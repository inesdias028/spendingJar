import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

class Category {
  final String key;
  final String label;
  final String emoji;

  /// true = a kind of money coming in (salary, gift…), false = spending.
  final bool income;

  const Category({required this.key, required this.label, required this.emoji, this.income = false});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        key: j['key'] as String,
        label: j['label'] as String,
        emoji: (j['emoji'] as String?) ?? '🏷️',
        income: (j['income'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'emoji': emoji, if (income) 'income': true};
}

/// One movement of money: spending (out) or income (in).
class Entry {
  final String id;

  /// Always positive. [income] says which way it goes.
  final double amount;
  final bool income;
  final String category;

  // A copy of the category's look, so old entries still show correctly
  // after their category is deleted.
  final String? emoji;
  final String? label;
  final DateTime date;

  const Entry({
    required this.id,
    required this.amount,
    required this.income,
    required this.category,
    this.emoji,
    this.label,
    required this.date,
  });

  /// + for income, − for spending.
  double get signed => income ? amount : -amount;

  /// Added automatically by a recurring item ('r_<series>_<date>').
  bool get isRecurring => id.startsWith('r_');

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'].toString(),
        amount: (j['amount'] as num).toDouble(),
        income: (j['income'] as bool?) ?? false,
        category: (j['category'] as String?) ?? 'other',
        emoji: j['emoji'] as String?,
        label: j['label'] as String?,
        date: DateTime.parse(j['date'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        if (income) 'income': true,
        'category': category,
        'emoji': emoji,
        'label': label,
        'date': date.toUtc().toIso8601String(),
      };
}

/// Money in or out that repeats every week, month or year.
class Recurring {
  final String id;
  final String name;
  final double amount;
  final bool income;
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
    required this.income,
    required this.category,
    required this.emoji,
    required this.label,
    required this.freq,
    required this.anchorDay,
    required this.next,
  });

  String get title => name.isEmpty ? label : name;

  /// Roughly what it adds (+) or takes (−) each month.
  double get perMonth =>
      (income ? amount : -amount) * (freq == Period.week ? 52 / 12 : freq == Period.month ? 1 : 1 / 12);

  Recurring copyWith({DateTime? next}) => Recurring(
        id: id,
        name: name,
        amount: amount,
        income: income,
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
        income: (j['income'] as bool?) ?? false,
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
        if (income) 'income': true,
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

const defaultIncomeCategories = <Category>[
  Category(key: 'salary', label: 'Salary', emoji: '💼', income: true),
  Category(key: 'gift_in', label: 'Gift', emoji: '🎁', income: true),
  Category(key: 'refund', label: 'Refund', emoji: '↩️', income: true),
  Category(key: 'sold', label: 'Sold', emoji: '🏷️', income: true),
  Category(key: 'income_other', label: 'Other', emoji: '💰', income: true),
];

const suggestedEmojis = ['🏋️', '🐶', '💊', '🎁', '✈️', '🏠', '📚', '🍺', '💇', '🎮', '🚗', '👶'];
const suggestedIncomeEmojis = ['💼', '💶', '🏦', '📈', '🧾', '🎓', '🤝', '🏆'];

// ---------------------------------------------------------------------------
// Store: holds one user's data and keeps it in sync with Firebase.
//
// Firestore layout (each user can only see their own, see firestore.rules):
//   users/{uid}                 -> { startBalance, categories, recurring, updatedAt }
//   users/{uid}/expenses/{id}   -> { amount, income?, category, emoji, label, date }
//
// Balance = startBalance + everything in − everything out.
// ---------------------------------------------------------------------------

class Store extends ChangeNotifier {
  Store(this.uid) : demo = false {
    _start();
  }

  /// Sample data that stays in memory, with no Firebase. Used by `--dart-define=DEMO=true`
  /// to try the app or take screenshots without signing in.
  Store.demo()
      : uid = 'demo',
        demo = true {
    final now = DateTime.now();
    DateTime ago(int days, int h, [int m = 0]) => DateTime(now.year, now.month, now.day - days, h, m);
    var n = 0;
    Entry e(double amount, Category c, DateTime d) =>
        Entry(id: 'demo${n++}', amount: amount, income: c.income, category: c.key, emoji: c.emoji, label: c.label, date: d);
    final cat = {for (final c in categories) c.key: c};
    startBalance = 350;
    entries = [
      e(4.5, cat['coffee']!, ago(0, 8, 40)),
      e(12.9, cat['food']!, ago(0, 13, 5)),
      e(25, cat['refund']!, ago(1, 18, 20)),
      e(2.1, cat['transport']!, ago(1, 9)),
      e(39.99, cat['shopping']!, ago(2, 17, 30)),
      e(18, cat['fun']!, ago(3, 21)),
      e(1450, cat['salary']!, ago(now.day - 1, 9)),
      e(64.3, cat['food']!, ago(6, 11)),
      e(3.2, cat['coffee']!, ago(8, 8)),
      e(50, cat['gift_in']!, ago(12, 15)),
      e(120, cat['shopping']!, ago(15, 16)),
      e(7.5, cat['coffee']!, ago(20, 10)),
      e(1450, cat['salary']!, DateTime(now.year, now.month - 1, 1, 9)),
      e(780, cat['other']!, DateTime(now.year, now.month - 1, 2, 9)),
      e(210, cat['food']!, DateTime(now.year, now.month - 1, 15, 9)),
    ]..sort((a, b) => b.date.compareTo(a.date));
    ready = true;
  }

  final String uid;

  /// true for [Store.demo]: nothing is sent to Firebase.
  final bool demo;

  // Data saved on this device by the earlier, no-login version of the app.
  static const _localKey = 'spending-jar-v1';

  /// What you had before you started tracking. Can be negative.
  double startBalance = 0;

  /// Money in or out that is added automatically on a schedule.
  List<Recurring> recurring = [];

  List<Entry> entries = [];
  List<Category> categories = [...defaultCategories, ...defaultIncomeCategories];

  /// True once the first data has arrived from Firebase.
  bool ready = false;

  /// Set if Firebase refused or failed (shown on screen instead of the app).
  String? error;

  bool _ranRecurring = false;
  bool _migratingExtras = false;

  late final _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expSub;
  bool _gotUser = false, _gotEntries = false;

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
        startBalance = (m['startBalance'] as num?)?.toDouble() ?? 0;
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
        // Accounts from before income existed get the default income categories.
        if (!categories.any((c) => c.income)) {
          categories = [...categories, ...defaultIncomeCategories];
        }
        final extras = m['extras'];
        if (extras is List && extras.isNotEmpty) _migrateExtras(extras);
      }
      _gotUser = true;
      _maybeReady();
    }, onError: _fail);

    _expSub = _expCol.snapshots().listen((q) {
      entries = q.docs.map((d) => Entry.fromJson({...d.data(), 'id': d.id})).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _gotEntries = true;
      _maybeReady();
    }, onError: _fail);
  }

  void _maybeReady() {
    if (_gotUser && _gotEntries) ready = true;
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

  /// The old budget version had "extra money" added to a week, month or year.
  /// With a balance, that is simply income, so it becomes income entries once.
  Future<void> _migrateExtras(List extras) async {
    if (_migratingExtras) return;
    _migratingExtras = true;
    try {
      final batch = _db.batch();
      for (final raw in extras) {
        final x = Map<String, dynamic>.from(raw as Map);
        final start = DateTime.parse(x['start'] as String);
        final note = ((x['note'] as String?) ?? '').trim();
        final e = Entry(
          id: 'x_${x['id']}',
          amount: (x['amount'] as num).toDouble(),
          income: true,
          category: 'income_other',
          emoji: '💰',
          label: note.isEmpty ? 'Extra money' : note,
          date: DateTime(start.year, start.month, start.day, 12),
        );
        // Fixed id: running this twice (two devices) writes the same entry.
        batch.set(_expCol.doc(e.id), e.toJson()..remove('id'));
      }
      batch.update(_userDoc, {'extras': []});
      await batch.commit();
    } catch (e) {
      _fail(e);
    } finally {
      _migratingExtras = false;
    }
  }

  /// A brand-new account: copy anything saved on this device into it.
  Future<void> _firstTimeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    var cats = <Category>[...defaultCategories, ...defaultIncomeCategories];
    var list = <Entry>[];
    if (raw != null) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (m['categories'] is List) {
          cats = [
            ...(m['categories'] as List).map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map))),
            ...defaultIncomeCategories,
          ];
        }
        list = ((m['expenses'] as List?) ?? [])
            .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        // Unreadable local data: start fresh.
      }
    }
    await _userDoc.set({
      'startBalance': 0,
      'recurring': [],
      'categories': cats.map((c) => c.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final e in list.skip(i).take(400)) {
        batch.set(_expCol.doc(_safeId(e.id)), e.toJson()..remove('id'));
      }
      await batch.commit();
    }
    if (raw != null) await prefs.remove(_localKey);
  }

  static String _safeId(String id) =>
      id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : id.replaceAll('/', '_');

  Future<void> _saveSettings() async {
    if (demo) return;
    await _userDoc.update({
        'startBalance': startBalance,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError(_fail);
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _expSub?.cancel();
    super.dispose();
  }

  // ---- numbers ----

  /// Your balance right now: what you started with, plus all income, minus all spending.
  double get balance => entries.fold(startBalance, (s, e) => s + e.signed);

  /// Balance just before [t].
  double balanceAt(DateTime t) =>
      entries.where((e) => e.date.isBefore(t)).fold(startBalance, (s, e) => s + e.signed);

  /// Money in and money out inside [start, end).
  ({double inc, double out}) totalsIn(DateTime start, DateTime end) {
    var inc = 0.0, out = 0.0;
    for (final e in entries) {
      if (e.date.isBefore(start) || !e.date.isBefore(end)) continue;
      if (e.income) {
        inc += e.amount;
      } else {
        out += e.amount;
      }
    }
    return (inc: inc, out: out);
  }

  List<Entry> between(DateTime start, DateTime end) =>
      entries.where((e) => !e.date.isBefore(start) && e.date.isBefore(end)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Category> categoriesOf({required bool income}) => categories.where((c) => c.income == income).toList();

  /// The category to show for an entry (falls back to its saved copy).
  Category categoryFor(Entry e) {
    for (final c in categories) {
      if (c.key == e.category) return c;
    }
    return Category(key: e.category, label: e.label ?? 'Deleted', emoji: e.emoji ?? '🏷️', income: e.income);
  }

  /// The name to show for an entry: a recurring item's own name, or its category.
  String titleFor(Entry e) => e.isRecurring && (e.label?.isNotEmpty ?? false) ? e.label! : categoryFor(e).label;

  // ---- actions (the screen updates straight away; Firebase syncs behind) ----

  void addEntry(double amount, Category c) {
    final e = Entry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      income: c.income,
      category: c.key,
      emoji: c.emoji,
      label: c.label,
      date: DateTime.now(),
    );
    entries = [e, ...entries];
    notifyListeners();
    if (!demo) _expCol.doc(e.id).set(e.toJson()..remove('id')).catchError(_fail);
  }

  void deleteEntry(String id) {
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
    if (!demo) _expCol.doc(id).delete().catchError(_fail);
  }

  void setStartBalance(double v) {
    startBalance = v;
    notifyListeners();
    _saveSettings();
  }

  /// Returns an error message, or null if the category was added.
  String? addCategory(String label, String emoji, {required bool income}) {
    final name = label.trim();
    if (name.isEmpty) return 'Give your category a name';
    if (categories.any((c) => c.income == income && c.label.toLowerCase() == name.toLowerCase())) {
      return 'You already have that category';
    }
    categories = [
      ...categories,
      Category(
        key: 'c${DateTime.now().millisecondsSinceEpoch}',
        label: name,
        emoji: emoji.trim().isEmpty ? (income ? '💰' : '🏷️') : emoji.trim(),
        income: income,
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

  /// Adds any recurring money in or out that has come due (up to today).
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
        final e = Entry(
          id: id,
          amount: item.amount,
          income: item.income,
          category: item.category,
          emoji: item.emoji,
          label: item.title,
          date: DateTime(d.year, d.month, d.day, 9),
        );
        if (demo) {
          entries = [e, ...entries.where((x) => x.id != id)]..sort((a, b) => b.date.compareTo(a.date));
        } else {
          _expCol.doc(id).set(e.toJson()..remove('id')).catchError(_fail);
        }
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
        income: category.income,
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
}

// ---------------------------------------------------------------------------
// Periods (week / month / year) and their date ranges
// ---------------------------------------------------------------------------

enum Period { week, month, year }

DateTime periodStart(Period p, DateTime d) => switch (p) {
      Period.week => startOfWeek(DateTime(d.year, d.month, d.day)),
      Period.month => DateTime(d.year, d.month, 1),
      Period.year => DateTime(d.year, 1, 1),
    };

DateTime periodEnd(Period p, DateTime start) => switch (p) {
      Period.week => DateTime(start.year, start.month, start.day + 7),
      Period.month => DateTime(start.year, start.month + 1, 1),
      Period.year => DateTime(start.year + 1, 1, 1),
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
          ? 'This Week'
          : offset == -1
              ? 'Last Week'
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

/// €1.234,50 — uses a real minus sign (−) for negatives.
String euro(double n) {
  final neg = n < -0.004;
  final fixed = n.abs().toStringAsFixed(2);
  final whole = fixed.substring(0, fixed.length - 3);
  final cents = fixed.substring(fixed.length - 2);
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${neg ? '−' : ''}€$grouped,$cents';
}

/// +€12,00 or −€4,50 (no sign for zero).
String signedEuro(double n) => n > 0.004 ? '+${euro(n)}' : euro(n);

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
const weekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// "Today", "Yesterday", "Monday", or "Thursday, 6 November" — like iOS lists.
String dayHeading(DateTime d) {
  final today = dayStart(DateTime.now());
  final day = dayStart(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return weekdayLong[d.weekday - 1];
  final y = d.year == today.year ? '' : ' ${d.year}';
  return '${weekdayLong[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]}$y';
}

String shortDate(DateTime d) => '${d.day} ${monthNames[d.month - 1].substring(0, 3)} ${d.year}';

String freqName(Period p) => switch (p) {
      Period.week => 'Weekly',
      Period.month => 'Monthly',
      Period.year => 'Yearly',
    };
