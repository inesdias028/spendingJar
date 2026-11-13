import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

class Category {
  final String key;
  final String label;
  final String emoji;

  const Category({required this.key, required this.label, required this.emoji});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        key: j['key'] as String,
        label: j['label'] as String,
        emoji: (j['emoji'] as String?) ?? '🏷️',
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'emoji': emoji};
}

class Expense {
  final String id;
  final double amount;
  final String category;
  // A copy of the category's look, so old entries still show correctly
  // after their category is deleted.
  final String? emoji;
  final String? label;
  final DateTime date;

  /// Set when a recurring payment added this, so its cost can be spread out.
  final Period? freq;

  /// For a one-off spending added in the month or year view: it belongs to that
  /// whole month or year, so smaller periods each get their part of it.
  final Period? spread;

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.emoji,
    this.label,
    required this.date,
    this.freq,
    this.spread,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'].toString(),
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] as String?) ?? 'other',
        emoji: j['emoji'] as String?,
        label: j['label'] as String?,
        date: DateTime.parse(j['date'] as String).toLocal(),
        freq: j['freq'] == null ? null : Period.values.where((p) => p.name == j['freq']).firstOrNull,
        spread: j['spread'] == null ? null : Period.values.where((p) => p.name == j['spread']).firstOrNull,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'emoji': emoji,
        'label': label,
        'date': date.toUtc().toIso8601String(),
        if (freq != null) 'freq': freq!.name,
        if (spread != null) 'spread': spread!.name,
      };
}

/// A spending that repeats every week, month or year.
class Recurring {
  final String id;
  final String name;
  final double amount;
  final String category;
  final String emoji;
  final String label;
  final Period freq;

  /// Day of the month it started on, so "31st" stays the last day in short months.
  final int anchorDay;

  /// The next date it will be added.
  final DateTime next;

  const Recurring({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.emoji,
    required this.label,
    required this.freq,
    required this.anchorDay,
    required this.next,
  });

  Recurring copyWith({DateTime? next}) => Recurring(
        id: id,
        name: name,
        amount: amount,
        category: category,
        emoji: emoji,
        label: label,
        freq: freq,
        anchorDay: anchorDay,
        next: next ?? this.next,
      );

  /// The date after [from] for this frequency.
  DateTime after(DateTime from) {
    switch (freq) {
      case Period.week:
        return DateTime(from.year, from.month, from.day + 7);
      case Period.month:
        return _clampDay(from.year, from.month + 1, anchorDay);
      case Period.year:
        return _clampDay(from.year + 1, from.month, anchorDay);
    }
  }

  static DateTime _clampDay(int y, int m, int d) {
    final first = DateTime(y, m, 1);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, d > last ? last : d);
  }

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] as String?) ?? 'other',
        emoji: (j['emoji'] as String?) ?? '🏷️',
        label: (j['label'] as String?) ?? 'Other',
        freq: Period.values.firstWhere((p) => p.name == j['freq'], orElse: () => Period.month),
        anchorDay: (j['anchorDay'] as num?)?.toInt() ?? 1,
        next: DateTime.parse(j['next'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'category': category,
        'emoji': emoji,
        'label': label,
        'freq': freq.name,
        'anchorDay': anchorDay,
        'next': '${next.year.toString().padLeft(4, '0')}-${two(next.month)}-${two(next.day)}',
      };
}

const defaultCategories = <Category>[
  Category(key: 'food', label: 'Food', emoji: '🍔'),
  Category(key: 'coffee', label: 'Coffee', emoji: '☕'),
  Category(key: 'transport', label: 'Transport', emoji: '🚌'),
  Category(key: 'shopping', label: 'Shopping', emoji: '🛍️'),
  Category(key: 'fun', label: 'Fun', emoji: '🎉'),
  Category(key: 'other', label: 'Other', emoji: '📦'),
];

const suggestedEmojis = ['🏋️', '🐶', '💊', '🎁', '✈️', '🏠', '📚', '🍺', '💇', '🎮', '🚗', '👶'];

// ---------------------------------------------------------------------------
// Store: holds one user's data and keeps it in sync with Firebase.
//
// Firestore layout (each user can only see their own, see firestore.rules):
//   users/{uid}                 -> { budget, categories, updatedAt }
//   users/{uid}/expenses/{id}   -> { amount, category, emoji, label, date }
// ---------------------------------------------------------------------------

class Store extends ChangeNotifier {
  Store(this.uid) {
    _start();
  }

  final String uid;

  // Data saved on this device by the earlier, no-login version of the app.
  static const _localKey = 'spending-jar-v1';

  /// Budget for each period. null = not set (worked out from the others).
  Map<Period, double?> budgets = {Period.week: 100, Period.month: null, Period.year: null};

  /// Which period the jar on the main screen tracks.
  Period jarPeriod = Period.week;

  /// Spending that is added automatically on a schedule.
  List<Recurring> recurring = [];
  bool _ranRecurring = false;
  List<Expense> expenses = [];
  List<Category> categories = List.of(defaultCategories);

  /// True once the first data has arrived from Firebase.
  bool ready = false;

  /// Set if Firebase refused or failed (shown on screen instead of the app).
  String? error;

  final _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expSub;
  bool _gotUser = false, _gotExpenses = false;

  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _expCol => _userDoc.collection('expenses');

  Future<void> _start() async {
    try {
      final snap = await _userDoc.get();
      if (!snap.exists) await _firstTimeSetup();
    } catch (e) {
      _fail(e);
      return;
    }

    _userSub = _userDoc.snapshots().listen((d) {
      final m = d.data();
      if (m != null) {
        final bm = m['budgets'];
        if (bm is Map) {
          budgets = {for (final p in Period.values) p: (bm[p.name] as num?)?.toDouble()};
        } else {
          budgets = {
            Period.week: (m['budget'] as num?)?.toDouble() ?? 100,
            Period.month: null,
            Period.year: null,
          };
        }
        jarPeriod = Period.values.firstWhere((p) => p.name == m['jarPeriod'], orElse: () => Period.week);
        if (m['recurring'] is List) {
          recurring = (m['recurring'] as List)
              .map((r) => Recurring.fromJson(Map<String, dynamic>.from(r as Map)))
              .toList();
        }
        if (m['categories'] is List) {
          categories = (m['categories'] as List)
              .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
        }
      }
      _gotUser = true;
      _maybeReady();
    }, onError: _fail);

    _expSub = _expCol.snapshots().listen((q) {
      expenses = q.docs.map((d) => Expense.fromJson({...d.data(), 'id': d.id})).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _gotExpenses = true;
      _maybeReady();
    }, onError: _fail);
  }

  void _maybeReady() {
    if (_gotUser && _gotExpenses) ready = true;
    notifyListeners();
    if (ready && !_ranRecurring) {
      _ranRecurring = true;
      runRecurring();
    }
  }

  void _fail(Object e) {
    error = e is FirebaseException ? (e.message ?? e.code) : e.toString();
    notifyListeners();
  }

  /// A brand-new account: copy anything saved on this device into it.
  Future<void> _firstTimeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    var b = 100.0;
    var cats = List<Category>.of(defaultCategories);
    var exps = <Expense>[];
    if (raw != null) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        b = (m['budget'] as num?)?.toDouble() ?? 100;
        if (m['categories'] is List) {
          cats = (m['categories'] as List)
              .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
        }
        exps = ((m['expenses'] as List?) ?? [])
            .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        // Unreadable local data: start fresh.
      }
    }
    await _writeAll(b, cats, exps);
    if (raw != null) await prefs.remove(_localKey);
  }

  /// Writes a new account's starting data.
  Future<void> _writeAll(double b, List<Category> cats, List<Expense> exps) async {
    await _userDoc.set({
      'budgets': {'week': b, 'month': null, 'year': null},
      'jarPeriod': 'week',
      'recurring': [],
      'categories': cats.map((c) => c.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < exps.length; i += 400) {
      final batch = _db.batch();
      for (final e in exps.skip(i).take(400)) {
        batch.set(_expCol.doc(_safeId(e.id)), e.toJson()..remove('id'));
      }
      await batch.commit();
    }
  }

  static String _safeId(String id) => id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : id.replaceAll('/', '_');

  Future<void> _saveSettings() => _userDoc.update({
        'budgets': {for (final p in Period.values) p.name: budgets[p]},
        'jarPeriod': jarPeriod.name,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError(_fail);

  @override
  void dispose() {
    _userSub?.cancel();
    _expSub?.cancel();
    super.dispose();
  }

  // ---- actions (the screen updates straight away; Firebase syncs behind) ----

  void addExpense(double amount, Category c) {
    final e = Expense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      category: c.key,
      emoji: c.emoji,
      label: c.label,
      date: DateTime.now(),
      spread: jarPeriod == Period.week ? null : jarPeriod,
    );
    _expCol.doc(e.id).set(e.toJson()..remove('id')).catchError(_fail);
  }

  void deleteExpense(String id) {
    _expCol.doc(id).delete().catchError(_fail);
  }

  /// Returns an error message, or null if the category was added.
  String? addCategory(String label, String emoji) {
    final name = label.trim();
    if (name.isEmpty) return 'Give your category a name';
    if (categories.any((c) => c.label.toLowerCase() == name.toLowerCase())) {
      return 'You already have that category';
    }
    categories = [
      ...categories,
      Category(
        key: 'c${DateTime.now().millisecondsSinceEpoch}',
        label: name,
        emoji: emoji.trim().isEmpty ? '🏷️' : emoji.trim(),
      ),
    ];
    notifyListeners();
    _saveSettings();
    return null;
  }

  void deleteCategory(String key) {
    categories = categories.where((c) => c.key != key).toList();
    notifyListeners();
    _saveSettings();
  }

  /// The pot as money per day, from the budget you set (week, then month, then year).
  /// There is one pot: the week, month and year budgets are the same money.
  double get perDay {
    for (final p in Period.values) {
      final v = budgets[p];
      if (v != null) return v / periodDays(p);
    }
    return 100 / 7;
  }

  bool isSet(Period p) => budgets[p] != null;

  /// The budget for a period: the same pot, measured over that period.
  double budgetFor(Period p, [int? days]) => perDay * periodDays(p);

  double estimateFor(Period p) => budgetFor(p);

  /// Which recurring series an automatic entry belongs to ('r_<series>_<date>').
  static String? seriesOf(Expense e) {
    if (!e.id.startsWith('r_')) return null;
    final i = e.id.lastIndexOf('_');
    return i > 2 ? e.id.substring(2, i) : null;
  }

  /// How an entry is shared out: its repeat, or the period it was added for.
  Period? spreadOf(Expense e) => freqOf(e) ?? e.spread;

  Period? freqOf(Expense e) {
    if (e.freq != null) return e.freq;
    final s = seriesOf(e);
    if (s == null) return null;
    for (final r in recurring) {
      if (r.id == s) return r.freq;
    }
    return null;
  }

  static DateTime _cycleEnd(DateTime from, Period f) => switch (f) {
        Period.week => DateTime(from.year, from.month, from.day + 7),
        Period.month => Recurring._clampDay(from.year, from.month + 1, from.day),
        Period.year => Recurring._clampDay(from.year + 1, from.month, from.day),
      };

  /// What each expense costs inside [start, end).
  /// A recurring payment that repeats less often than the range is long is spread
  /// evenly: 100 a month counts as about 23 in a week and 1200 in a year.
  Map<Expense, double> sharesIn(DateTime start, DateTime end) {
    final n = (end.difference(start).inHours / 24).round();
    final len = n < 28 ? n.toDouble() : (n <= 31 ? 365.25 / 12 : 365.25);
    final out = <Expense, double>{};
    final series = <String, List<Expense>>{};
    final lookBack = start.subtract(const Duration(days: 370));
    for (final e in expenses) {
      final f = freqOf(e);
      final sp = e.spread;
      if (f == null && sp != null && periodDays(sp) > len + 3) {
        // One-off monthly or yearly spending: share it by days over its month or year.
        final cs = sp == Period.month ? DateTime(e.date.year, e.date.month, 1) : DateTime(e.date.year, 1, 1);
        final ce = sp == Period.month ? DateTime(cs.year, cs.month + 1, 1) : DateTime(cs.year + 1, 1, 1);
        final from = start.isAfter(cs) ? start : cs;
        final to = end.isBefore(ce) ? end : ce;
        final overlap = (to.difference(from).inHours / 24).round();
        if (overlap > 0) {
          out[e] = e.amount * overlap / (ce.difference(cs).inHours / 24).round();
        }
        continue;
      }
      if (f == null || periodDays(f) <= len + 0.01) {
        if (!e.date.isBefore(start) && e.date.isBefore(end)) out[e] = e.amount;
      } else if (e.date.isBefore(end) && e.date.isAfter(lookBack)) {
        series.putIfAbsent(seriesOf(e) ?? e.id, () => []).add(e);
      }
    }
    for (final list in series.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
      Expense? pick;
      for (final e in list) {
        final from = dayStart(e.date);
        if (!from.isAfter(start) && _cycleEnd(from, freqOf(e)!).isAfter(start)) {
          pick = e;
          break;
        }
      }
      pick ??= list.where((e) => !e.date.isBefore(start)).firstOrNull;
      if (pick != null) out[pick] = pick.amount * len / periodDays(freqOf(pick)!);
    }
    return out;
  }

  double spentIn(DateTime start, DateTime end) => sharesIn(start, end).values.fold(0.0, (s, v) => s + v);

  void setBudgets(Map<Period, double?> value) {
    budgets = Map.of(value);
    notifyListeners();
    _saveSettings();
  }

  /// Adds any recurring spending that has come due (up to today).
  /// Safe to run on several devices: each date gets one fixed id.
  Future<void> runRecurring() async {
    final today = dayStart(DateTime.now());
    var changed = false;
    final updated = <Recurring>[];
    for (final r in recurring) {
      var item = r;
      var guard = 0;
      while (!item.next.isAfter(today) && guard < 500) {
        final d = item.next;
        final id = 'r_${item.id}_${d.year}${two(d.month)}${two(d.day)}';
        final e = Expense(
          id: id,
          amount: item.amount,
          category: item.category,
          emoji: item.emoji,
          label: item.name.isEmpty ? item.label : item.name,
          date: DateTime(d.year, d.month, d.day, 9),
          freq: item.freq,
        );
        _expCol.doc(id).set(e.toJson()..remove('id')).catchError(_fail);
        item = item.copyWith(next: item.after(d));
        changed = true;
        guard++;
      }
      updated.add(item);
    }
    if (changed) {
      recurring = updated;
      notifyListeners();
      await _saveSettings();
    }
  }

  void addRecurring({
    required String name,
    required double amount,
    required Category category,
    required Period freq,
    required DateTime start,
  }) {
    final s = dayStart(start);
    recurring = [
      ...recurring,
      Recurring(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        amount: amount,
        category: category.key,
        emoji: category.emoji,
        label: category.label,
        freq: freq,
        anchorDay: s.day,
        next: s,
      ),
    ];
    notifyListeners();
    _saveSettings().then((_) => runRecurring());
  }

  void deleteRecurring(String id) {
    recurring = recurring.where((r) => r.id != id).toList();
    notifyListeners();
    _saveSettings();
  }

  void setJarPeriod(Period p) {
    jarPeriod = p;
    notifyListeners();
    _saveSettings();
  }

  /// The category to show for an expense (falls back to its saved copy).
  Category categoryFor(Expense e) {
    for (final c in categories) {
      if (c.key == e.category) return c;
    }
    return Category(key: e.category, label: e.label ?? 'Deleted', emoji: e.emoji ?? '🏷️');
  }

  List<Expense> between(DateTime start, DateTime end) => expenses
      .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

// ---------------------------------------------------------------------------
// Periods (week / month / year) and their date ranges
// ---------------------------------------------------------------------------

enum Period { week, month, year }

/// Days in each period, used to turn one budget into the others.
double periodDays(Period p) => switch (p) {
      Period.week => 7,
      Period.month => 365.25 / 12,
      Period.year => 365.25,
    };

extension PeriodWords on Period {
  /// "week", "month", "year"
  String get word => name;
  String get title => '${name[0].toUpperCase()}${name.substring(1)}';
}

class Bucket {
  Bucket(this.start, this.end, this.label);
  final DateTime start;
  final DateTime end;
  final String label;
}

class PeriodRange {
  PeriodRange(this.start, this.end, this.buckets, this.label);
  final DateTime start;
  final DateTime end;
  final List<Bucket> buckets;
  final String label;

  /// Whole days in the period (DST-safe).
  int get days => DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
}

PeriodRange rangeFor(Period p, int offset) {
  final now = DateTime.now();
  switch (p) {
    case Period.week:
      final base = startOfWeek(now);
      final start = DateTime(base.year, base.month, base.day + offset * 7);
      final end = DateTime(start.year, start.month, start.day + 7);
      final buckets = [
        for (var i = 0; i < 7; i++)
          Bucket(
            DateTime(start.year, start.month, start.day + i),
            DateTime(start.year, start.month, start.day + i + 1),
            weekdayShort[i].substring(0, 1),
          ),
      ];
      final last = DateTime(end.year, end.month, end.day - 1);
      final label = offset == 0
          ? 'This week'
          : offset == -1
              ? 'Last week'
              : '${start.day} ${monthNames[start.month - 1].substring(0, 3)} – '
                  '${last.day} ${monthNames[last.month - 1].substring(0, 3)}';
      return PeriodRange(start, end, buckets, label);

    case Period.month:
      final start = DateTime(now.year, now.month + offset, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      final n = DateTime(start.year, start.month + 1, 0).day;
      final buckets = [
        for (var d = 1; d <= n; d++)
          Bucket(
            DateTime(start.year, start.month, d),
            DateTime(start.year, start.month, d + 1),
            (d == 1 || d % 5 == 0) ? '$d' : '',
          ),
      ];
      return PeriodRange(start, end, buckets, '${monthNames[start.month - 1]} ${start.year}');

    case Period.year:
      final start = DateTime(now.year + offset, 1, 1);
      final end = DateTime(start.year + 1, 1, 1);
      final buckets = [
        for (var m = 1; m <= 12; m++)
          Bucket(DateTime(start.year, m, 1), DateTime(start.year, m + 1, 1), monthNames[m - 1].substring(0, 1)),
      ];
      return PeriodRange(start, end, buckets, '${start.year}');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String euro(double n) {
  final neg = n < 0;
  return '${neg ? '-' : ''}€${n.abs().toStringAsFixed(2).replaceAll('.', ',')}';
}

/// Accepts "4,50" and "4.50". Returns null for empty, invalid or zero.
double? parseAmount(String text) {
  final n = double.tryParse(text.trim().replaceAll(',', '.'));
  if (n == null || n <= 0) return null;
  return (n * 100).roundToDouble() / 100;
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday 00:00 of the week containing [d].
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String two(int n) => n.toString().padLeft(2, '0');

/// e.g. "Thu 12 · 09:05"
String shortDateTime(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} · ${two(d.hour)}:${two(d.minute)}';
