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
        final items = store.between(r.start, r.end);
        final spent = items.fold<double>(0, (s, e) => s + e.amount);
        final budget = store.budgetFor(period, r.days);
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
                                      'Budget ${euro(budget)} / ${period.word}${store.isSet(period) ? '' : ' (auto)'}',
                                      style: const TextStyle(color: AppColors.blue, fontSize: 15),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_right, size: 15, color: AppColors.blue),
                                ],
                              ),
                            ),
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
                GroupHeader(_repeat == null ? 'Tap a category to add' : 'Tap a category to add as recurring'),
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
  const _ExpenseRow({super.key, required this.expense, required this.category, required this.onDelete});
  final Expense expense;
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
                  Text(shortDateTime(expense.date), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            Text(euro(expense.amount), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
  late final Map<Period, TextEditingController> _ctrls = {
    for (final p in Period.values)
      p: TextEditingController(
        text: widget.store.isSet(p) ? widget.store.budgets[p]!.toStringAsFixed(2).replaceAll('.', ',') : '',
      ),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final out = <Period, double?>{};
    for (final p in Period.values) {
      final t = _ctrls[p]!.text.trim();
      if (t.isEmpty) {
        out[p] = null;
        continue;
      }
      final v = parseAmount(t);
      if (v == null) {
        setState(() => _error = 'The ${p.word} budget should be an amount, like 400 or 12,50.');
        return;
      }
      out[p] = v;
    }
    widget.store.setBudgets(out);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IosSheet(
      title: 'Budgets',
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
                            placeholder: 'Auto (${euro(widget.store.estimateFor(p))})',
                            prefix: const Text('€', style: TextStyle(color: AppColors.muted, fontSize: 17)),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
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
              _error ?? 'Set a goal for any period. Leave one empty and it is worked out from the others.',
              style: TextStyle(fontSize: 13, color: _error != null ? AppColors.red : AppColors.muted),
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
