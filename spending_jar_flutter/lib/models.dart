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

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.emoji,
    this.label,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'].toString(),
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] as String?) ?? 'other',
        emoji: j['emoji'] as String?,
        label: j['label'] as String?,
        date: DateTime.parse(j['date'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'emoji': emoji,
        'label': label,
        'date': date.toUtc().toIso8601String(),
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

  /// Money per day, from the first budget that is set (week, then month, then year).
  double get _perDay {
    final w = budgets[Period.week], mo = budgets[Period.month], y = budgets[Period.year];
    if (w != null) return w / 7;
    if (mo != null) return mo * 12 / 365.25;
    if (y != null) return y / 365.25;
    return 100 / 7;
  }

  bool isSet(Period p) => budgets[p] != null;

  /// The budget for a period of [days] days: the one you set, or an estimate.
  double budgetFor(Period p, int days) => budgets[p] ?? _perDay * days;

  /// What an unset budget would be, for a typical period of that kind.
  double estimateFor(Period p) => _perDay * (p == Period.week ? 7 : p == Period.month ? 365.25 / 12 : 365.25);

  void setBudgets(Map<Period, double?> value) {
    budgets = Map.of(value);
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
