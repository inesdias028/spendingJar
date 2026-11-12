import 'dart:convert';

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
// Store: holds everything and saves it on the device
// ---------------------------------------------------------------------------

class Store extends ChangeNotifier {
  // Same key and JSON shape as the website, so backups move between them.
  static const _storageKey = 'spending-jar-v1';

  double budget = 100;
  List<Expense> expenses = [];
  List<Category> categories = List.of(defaultCategories);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _apply(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    notifyListeners();
  }

  void _apply(Map<String, dynamic> m) {
    budget = (m['budget'] as num?)?.toDouble() ?? 100;
    expenses = ((m['expenses'] as List?) ?? [])
        .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (m['categories'] is List) {
      categories = (m['categories'] as List)
          .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
    }
  }

  Map<String, dynamic> _toJson() => {
        'budget': budget,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---- actions ----

  void addExpense(double amount, Category c) {
    expenses.insert(
      0,
      Expense(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: amount,
        category: c.key,
        emoji: c.emoji,
        label: c.label,
        date: DateTime.now(),
      ),
    );
    _changed();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    _changed();
  }

  /// Returns an error message, or null if the category was added.
  String? addCategory(String label, String emoji) {
    final name = label.trim();
    if (name.isEmpty) return 'Give your category a name';
    if (categories.any((c) => c.label.toLowerCase() == name.toLowerCase())) {
      return 'You already have that category';
    }
    categories.add(Category(
      key: 'c${DateTime.now().millisecondsSinceEpoch}',
      label: name,
      emoji: emoji.trim().isEmpty ? '🏷️' : emoji.trim(),
    ));
    _changed();
    return null;
  }

  void deleteCategory(String key) {
    categories.removeWhere((c) => c.key == key);
    _changed();
  }

  void setBudget(double value) {
    budget = value;
    _changed();
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

  // ---- backup ----

  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'app': 'spending-jar',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        ..._toJson(),
      });

  /// Returns the parsed backup if [text] is a valid Spending Jar backup.
  static Map<String, dynamic>? parseBackup(String text) {
    try {
      final m = Map<String, dynamic>.from(jsonDecode(text) as Map);
      if (m['app'] != 'spending-jar') return null;
      if (m['budget'] is! num || m['expenses'] is! List || m['categories'] is! List) return null;
      // Make sure every entry can be read.
      for (final e in m['expenses'] as List) {
        Expense.fromJson(Map<String, dynamic>.from(e as Map));
      }
      return m;
    } catch (_) {
      return null;
    }
  }

  void restore(Map<String, dynamic> backup) {
    _apply(backup);
    _changed();
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
