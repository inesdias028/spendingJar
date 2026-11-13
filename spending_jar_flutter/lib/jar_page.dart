import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';
import 'recurring_page.dart';

class JarPage extends StatefulWidget {
  const JarPage({super.key, required this.store});
  final Store store;

  @override
  State<JarPage> createState() => _JarPageState();
}

class _JarPageState extends State<JarPage> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  Period? _repeat; // null = one-off

  Store get store => widget.store;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEE1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _add(Category c) {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      _toast('Type an amount first, like 4,50');
      _amountFocus.requestFocus();
      return;
    }
    HapticFeedback.lightImpact();
    final repeat = _repeat;
    if (repeat == null) {
      store.addExpense(amount, c);
    } else {
      store.addRecurring(name: '', amount: amount, category: c, freq: repeat, start: DateTime.now());
      _toast('${c.label} repeats ${freqName(repeat).toLowerCase()} from today');
    }
    _amount.clear();
    _amountFocus.unfocus();
    setState(() => _repeat = null);
  }

  void _categoryMenu(Category c) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('${c.emoji}  ${c.label}'),
        message: const Text('Past spending in this category stays in your list.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteCategory(c.key);
            },
            child: const Text('Delete category'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _editBudgets() {
    showCupertinoModalPopup<void>(context: context, builder: (_) => _BudgetsSheet(store: store));
  }

  void _newCategory() {
    showCupertinoModalPopup<void>(context: context, builder: (_) => _NewCategorySheet(store: store));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final period = store.jarPeriod;
        final r = rangeFor(period, 0);
        // Each entry with what it costs in this period: recurring payments are
        // divided, so the list adds up to the jar and the battery.
        final shares = store.sharesIn(r.start, r.end);
        final items = shares.keys.toList()..sort((a, b) => b.date.compareTo(a.date));
        final spent = shares.values.fold<double>(0, (s, v) => s + v);
        final extra = store.extraIn(r.start, r.end);
        final budget = store.budgetFor(period, r.days) + extra;
        final left = budget - spent;
        final fill = budget > 0 ? (left / budget).clamp(0.0, 1.0) : 0.0;
        final color = fill > 0.5 ? AppColors.green : (fill > 0.2 ? AppColors.orange : AppColors.red);

        return SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const LargeTitle('Spending Jar'),

                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<Period>(
                    groupValue: period,
                    children: const {
                      Period.week: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Week')),
                      Period.month: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Month')),
                      Period.year: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Year')),
                    },
                    onValueChanged: (p) {
                      if (p != null) store.setJarPeriod(p);
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ---- Battery + summary ----
                InsetCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      JarGraphic(fill: fill, color: color),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Left this ${period.word}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                euro(left),
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                  color: left < 0 ? AppColors.red : AppColors.text,
                                ),
                              ),
                            ),
                            Text('Spent ${euro(spent)}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _editBudgets,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Budget ${euro(budget)} / ${period.word}',
                                      style: const TextStyle(color: AppColors.blue, fontSize: 15),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_right, size: 15, color: AppColors.blue),
                                ],
                              ),
                            ),
                            if (extra > 0.005)
                              Text('incl. +${euro(extra)} extra',
                                  style: const TextStyle(color: AppColors.darkGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- Amount ----
                CupertinoTextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  placeholder: '€ 0,00',
                  placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 34, fontWeight: FontWeight.w600),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: AppColors.text),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 10),
                InsetCard(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.repeat, size: 20, color: AppColors.blue),
                      const SizedBox(width: 10),
                      const Text('Repeat', style: TextStyle(fontSize: 17)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: _repeat == null ? -1 : _repeat!.index,
                          children: const {
                            -1: Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text('Never', style: TextStyle(fontSize: 13))),
                            0: Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text('Week', style: TextStyle(fontSize: 13))),
                            1: Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text('Month', style: TextStyle(fontSize: 13))),
                            2: Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text('Year', style: TextStyle(fontSize: 13))),
                          },
                          onValueChanged: (v) => setState(() => _repeat = (v == null || v < 0) ? null : Period.values[v]),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- Categories ----
                GroupHeader(_repeat != null
                    ? 'Tap a category to add as recurring'
                    : period == Period.week
                        ? 'Tap a category to add'
                        : 'Tap a category to add for this ${period.word}'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.2,
                  children: [
                    for (final c in store.categories)
                      CategoryTile(
                        emoji: c.emoji,
                        label: c.label,
                        onTap: () => _add(c),
                        onLongPress: () => _categoryMenu(c),
                      ),
                    CategoryTile(emoji: '', label: 'New', isNew: true, onTap: _newCategory),
                  ],
                ),

                // ---- This period ----
                GroupHeader('This ${period.word}'),
                if (items.isEmpty)
                  const InsetCard(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text('Nothing yet. Your battery is full.',
                          style: TextStyle(color: AppColors.muted, fontSize: 15)),
                    ),
                  )
                else
                  InsetCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const RowDivider(indent: 62),
                          _ExpenseRow(
                            key: ValueKey(items[i].id),
                            expense: items[i],
                            share: shares[items[i]]!,
                            freq: store.spreadOf(items[i]),
                            category: store.categoryFor(items[i]),
                            onDelete: () => store.deleteExpense(items[i].id),
                          ),
                        ],
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Swipe left on an entry to delete it. Hold a category to remove it.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                if (store.recurring.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: InsetCard(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        onPressed: () => showCupertinoModalPopup<void>(
                          context: context,
                          builder: (_) => RecurringSheet(store: store),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.repeat, size: 20, color: AppColors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Recurring spending (${store.recurring.length})',
                                  style: const TextStyle(fontSize: 17, color: AppColors.text)),
                            ),
                            const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Rows and tiles
// ---------------------------------------------------------------------------

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    super.key,
    required this.expense,
    required this.share,
    required this.freq,
    required this.category,
    required this.onDelete,
  });
  final Expense expense;

  /// What this entry costs in the period shown (less than the amount when divided).
  final double share;
  final Period? freq;
  final Category category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('d-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      confirmDismiss: (_) => confirmIos(context, 'Delete ${euro(expense.amount)}?'),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      child: Container(
        color: AppColors.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: Text(category.emoji, style: const TextStyle(fontSize: 19)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(category.label, style: const TextStyle(fontSize: 17))),
                      if (expense.id.startsWith('r_')) ...[
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.repeat, size: 14, color: AppColors.muted),
                      ],
                    ],
                  ),
                  Text(
                    (share - expense.amount).abs() > 0.005
                        ? '${euro(expense.amount)} ${freq == null ? '' : (expense.id.startsWith('r_') ? freqName(freq!).toLowerCase() : 'this ${freq!.word}')}, divided · ${shortDateTime(expense.date)}'
                        : shortDateTime(expense.date),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(euro(share), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isNew = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isNew;

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              setState(() => _down = false);
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _down ? const Color(0xFFE9E9EE) : AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isNew)
                const Icon(CupertinoIcons.add_circled, size: 30, color: AppColors.blue)
              else
                Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: widget.isNew ? AppColors.blue : const Color(0xFF3C3C43)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

class _BudgetsSheet extends StatefulWidget {
  const _BudgetsSheet({required this.store});
  final Store store;

  @override
  State<_BudgetsSheet> createState() => _BudgetsSheetState();
}

class _BudgetsSheetState extends State<_BudgetsSheet> {
  static String _fmt(double v) {
    final t = v.toStringAsFixed(2).replaceAll('.', ',');
    return t.endsWith(',00') ? t.substring(0, t.length - 3) : t;
  }

  late final Map<Period, TextEditingController> _ctrls = {
    for (final p in Period.values) p: TextEditingController(text: _fmt(widget.store.budgetFor(p))),
  };
  Period? _source;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Typing in one period fills in the others: it is the same pot.
  void _changed(Period p, String text) {
    _source = p;
    final v = parseAmount(text.trim());
    setState(() => _error = null);
    if (v == null) return;
    for (final q in Period.values) {
      if (q != p) _ctrls[q]!.text = _fmt(v / periodDays(p) * periodDays(q));
    }
  }

  void _save() {
    final p = _source;
    if (p == null) {
      Navigator.pop(context);
      return;
    }
    final v = parseAmount(_ctrls[p]!.text.trim());
    if (v == null || v <= 0) {
      setState(() => _error = 'The ${p.word} budget should be an amount, like 400 or 12,50.');
      return;
    }
    widget.store.setBudgets({for (final q in Period.values) q: q == p ? v : null});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IosSheet(
      title: 'Budget',
      doneLabel: 'Save',
      onDone: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsetCard(
            child: Column(
              children: [
                for (final p in Period.values) ...[
                  if (p != Period.week) const RowDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 110, child: Text('Per ${p.word}', style: const TextStyle(fontSize: 17))),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _ctrls[p],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            prefix: const Text('€', style: TextStyle(color: AppColors.muted, fontSize: 17)),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onChanged: (t) => _changed(p, t),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _error ??
                  'One pot, shown three ways. Change any period and the others follow '
                      '(a month is about 4.35 weeks). Recurring payments are spread the same way: '
                      '100 a month takes about 23 from each week.',
              style: TextStyle(fontSize: 13, color: _error != null ? AppColors.red : AppColors.muted),
            ),
          ),
          const GroupHeader('Extra money'),
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final now = DateTime.now();
              final list = widget.store.extras.where((x) => x.end.isAfter(now)).toList()
                ..sort((a, b) => a.start.compareTo(b.start));
              return InsetCard(
                child: Column(
                  children: [
                    for (final x in list) ...[
                      Dismissible(
                        key: ValueKey('x-${x.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        confirmDismiss: (_) => confirmIos(context, 'Remove +${euro(x.amount)} extra?'),
                        onDismissed: (_) => widget.store.deleteExtra(x.id),
                        child: Container(
                          color: AppColors.card,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(x.note.isEmpty ? 'Extra' : x.note, style: const TextStyle(fontSize: 17)),
                                    Text(extraWhen(x), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Text('+${euro(x.amount)}',
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.darkGreen)),
                            ],
                          ),
                        ),
                      ),
                      const RowDivider(),
                    ],
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      onPressed: () => showCupertinoModalPopup<void>(
                        context: context,
                        builder: (_) => _ExtraSheet(store: widget.store),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.add_circled_solid, color: AppColors.green, size: 22),
                          SizedBox(width: 10),
                          Text('Add extra money', style: TextStyle(fontSize: 17)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Extra money counts only for the week, month or year you add it to. Swipe left to remove one.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

String extraWhen(Extra x) => switch (x.period) {
      Period.week => 'Week of ${x.start.day} ${monthNames[x.start.month - 1].substring(0, 3)}',
      Period.month => '${monthNames[x.start.month - 1]} ${x.start.year}',
      Period.year => 'Year ${x.start.year}',
    };

class _ExtraSheet extends StatefulWidget {
  const _ExtraSheet({required this.store});
  final Store store;

  @override
  State<_ExtraSheet> createState() => _ExtraSheetState();
}

class _ExtraSheetState extends State<_ExtraSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late Period _period = widget.store.jarPeriod;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_amount.text.trim());
    if (v == null || v <= 0) {
      setState(() => _error = 'Type an amount, like 300 or 25,50.');
      return;
    }
    widget.store.addExtra(v, _note.text, _period);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IosSheet(
      title: 'Extra Money',
      doneLabel: 'Add',
      onDone: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsetCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    placeholder: 'Amount, like 300',
                    prefix: const Text('+ €', style: TextStyle(color: AppColors.darkGreen, fontSize: 17)),
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _note,
                    placeholder: 'Note, like Bonus (optional)',
                    maxLength: 24,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.red)),
            ),
          const GroupHeader('Only for'),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<Period>(
              groupValue: _period,
              children: const {
                Period.week: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('This week')),
                Period.month: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('This month')),
                Period.year: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('This year')),
              },
              onValueChanged: (p) {
                if (p != null) setState(() => _period = p);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Adds to ${extraWhen(Extra(id: '', amount: 0, note: '', period: _period, start: periodStart(_period, DateTime.now())))} only. '
              '${_period == Period.week ? '' : 'Each week gets its part of it.'}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewCategorySheet extends StatefulWidget {
  const _NewCategorySheet({required this.store});
  final Store store;

  @override
  State<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<_NewCategorySheet> {
  final _emoji = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emoji.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final err = widget.store.addCategory(_name.text, _emoji.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IosSheet(
      title: 'New Category',
      doneLabel: 'Add',
      onDone: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsetCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _emoji,
                    placeholder: 'Emoji 🏷️',
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _name,
                    autofocus: true,
                    placeholder: 'Name, like Gym',
                    maxLength: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.red)),
            ),
          const GroupHeader('Suggestions'),
          InsetCard(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final e in suggestedEmojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji.text = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emoji.text == e ? const Color(0xFFD9E9FF) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Battery
// ---------------------------------------------------------------------------

/// A battery that empties as you spend. [fill] is 0..1.
class JarGraphic extends StatelessWidget {
  const JarGraphic({super.key, required this.fill, required this.color});
  final double fill;
  final Color color;

  static const double w = 76, h = 130;
  static const double capW = 30, capH = 9;
  static const double border = 3.5, gap = 4;

  @override
  Widget build(BuildContext context) {
    const bodyH = h - capH;
    const innerH = bodyH - 2 * border - 2 * gap;
    return SizedBox(
      width: w,
      height: h,
      child: Column(
        children: [
          Container(
            width: capW,
            height: capH,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          Container(
            width: w,
            height: bodyH,
            padding: const EdgeInsets.all(gap),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A3A3C), width: border),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: innerH * fill,
                  width: double.infinity,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${(fill * 100).round()}%',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: fill > 0.55 ? Colors.white : const Color(0xFF3A3A3C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
