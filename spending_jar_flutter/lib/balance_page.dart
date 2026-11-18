import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';
import 'recurring_page.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({super.key, required this.store});
  final Store store;

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _note = TextEditingController(); // optional reason for the amount
  bool _income = false;
  Period? _repeat; // null = one-off

  /// Edit mode for the category grid: each tile shows a red badge to remove it.
  bool _editingCategories = false;

  /// How many entries the activity list shows; "Show More" adds another page.
  static const _page = 40;
  int _shown = _page;

  Store get store => widget.store;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  void _add(Category c) {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      HapticFeedback.heavyImpact();
      showToast(context, 'Type an amount first, like 4,50');
      _amountFocus.requestFocus();
      return;
    }
    HapticFeedback.lightImpact();
    final repeat = _repeat;
    final note = _note.text.trim();
    if (repeat == null) {
      store.addEntry(amount, c, note: note);
      showToast(context, '${c.emoji} ${note.isEmpty ? c.label : note}  ${signedEuro(c.income ? amount : -amount)}');
    } else {
      // For something that repeats, the note becomes its name (e.g. "Netflix").
      store.addRecurring(name: note, amount: amount, category: c, freq: repeat, start: DateTime.now());
      showToast(context, '${note.isEmpty ? c.label : note} repeats ${freqName(repeat).toLowerCase()} from today');
    }
    _amount.clear();
    _note.clear();
    FocusScope.of(context).unfocus();
    _amountFocus.unfocus();
    setState(() => _repeat = null);
  }

  Future<void> _confirmDeleteCategory(Category c) async {
    final ok = await confirmIos(
      context,
      'Delete \u201C${c.label}\u201D?',
      message: 'Past entries in this category stay in your list.',
      ok: 'Delete Category',
    );
    if (!ok) return;
    HapticFeedback.mediumImpact();
    store.deleteCategory(c.key);
    if (store.categoriesOf(income: _income).isEmpty) setState(() => _editingCategories = false);
  }

  /// The Repeat menu, like the iPhone app's pull-down: Never, Weekly, Monthly, Yearly.
  void _pickRepeat() {
    // `sheetContext` is the menu's own context: popping it closes only the menu.
    Widget option(BuildContext sheetContext, String label, Period? p) => CupertinoActionSheetAction(
          isDefaultAction: _repeat == p,
          onPressed: () {
            Navigator.pop(sheetContext);
            setState(() => _repeat = p);
          },
          child: Text(label),
        );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Repeat'),
        actions: [
          option(ctx, 'Never', null),
          for (final p in Period.values) option(ctx, freqName(p), p),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Everything, newest first. Older entries come in pages as you ask for them.
        final all = store.entries;
        final items = all.take(_shown).toList();
        final month = rangeFor(Period.month, 0);
        final mt = store.totalsIn(month.start, month.end);
        final cats = store.categoriesOf(income: _income);

        // Entries grouped by day, newest first, like Wallet.
        final days = <DateTime, List<Entry>>{};
        for (final e in items) {
          days.putIfAbsent(dayStart(e.date), () => []).add(e);
        }

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: LargeTitlePage(
            title: 'Balance',
            trailing: GlassIconButton(
              icon: CupertinoIcons.repeat,
              label: 'Recurring',
              onPressed: () => presentSheet<void>(context, (_, c) => RecurringSheet(store: store, controller: c)),
            ),
            children: [
              const SizedBox(height: 4),
              _BalanceCard(
                balance: store.balance,
                monthIn: mt.inc,
                monthOut: mt.out,
                onTap: () => presentSheet<void>(context, (_, c) => BalanceSheet(store: store, controller: c)),
              ),

              // ---- New entry ----
              const GroupHeader('New entry'),
              InsetCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<bool>(
                          groupValue: _income,
                          thumbColor: const CupertinoDynamicColor.withBrightness(
                              color: Color(0xFFFFFFFF), darkColor: Color(0xFF636366)),
                          children: const {
                            false: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Spending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                            true: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Income', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                          },
                          onValueChanged: (v) {
                            if (v == null) return;
                            HapticFeedback.selectionClick();
                            setState(() {
                              _income = v;
                              _editingCategories = false;
                            });
                          },
                        ),
                      ),
                    ),
                    CupertinoTextField(
                      controller: _amount,
                      focusNode: _amountFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      // Amount right after the sign, like the iPhone app ("− € 0,00").
                      placeholder: '0,00',
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 18, right: 6),
                        child: Text(
                          _income ? '+ €' : '− €',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: (_income ? AppColors.green : AppColors.muted).of(context),
                          ),
                        ),
                      ),
                      placeholderStyle: TextStyle(
                          color: AppColors.faint.of(context), fontSize: 34, fontWeight: FontWeight.w600),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: (_income ? AppColors.green : AppColors.label).of(context),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: null,
                      textInputAction: TextInputAction.next,
                    ),
                    Container(
                        margin: const EdgeInsets.only(left: 16), height: 0.5, color: AppColors.separator.of(context)),
                    // Optional reason for the amount ("Dinner with Ana").
                    CupertinoTextField(
                      controller: _note,
                      placeholder: _income ? 'Note (optional), like Birthday money' : 'Note (optional), like Dinner with Ana',
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Icon(CupertinoIcons.pencil, size: 18, color: AppColors.muted.of(context)),
                      ),
                      clearButtonMode: OverlayVisibilityMode.editing,
                      padding: const EdgeInsets.fromLTRB(10, 13, 16, 13),
                      decoration: null,
                    ),
                    Container(
                        margin: const EdgeInsets.only(left: 16), height: 0.5, color: AppColors.separator.of(context)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickRepeat,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            const Text('Repeat', style: TextStyle(fontSize: 17)),
                            const Spacer(),
                            Text(_repeat == null ? 'Never' : freqName(_repeat!),
                                style: TextStyle(fontSize: 17, color: AppColors.muted.of(context))),
                            const SizedBox(width: 4),
                            Icon(CupertinoIcons.chevron_up_chevron_down, size: 15, color: AppColors.muted.of(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Categories ----
              GroupHeader(
                _editingCategories
                    ? 'Tap a category to delete it'
                    : _repeat != null
                        ? 'Tap a category to make it repeat'
                        : _income
                            ? 'Tap where the money came from'
                            : 'Tap a category to add',
                trailing: cats.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: () => setState(() => _editingCategories = !_editingCategories),
                        child: Text(
                          _editingCategories ? 'Done' : 'Edit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _editingCategories ? FontWeight.w600 : FontWeight.w400,
                            color: AppColors.accent.of(context),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    for (final c in cats)
                      CategoryTile(
                        emoji: c.emoji,
                        label: c.label,
                        removable: _editingCategories,
                        // In edit mode a tap removes the category (after asking); otherwise it adds.
                        onTap: () => _editingCategories ? _confirmDeleteCategory(c) : _add(c),
                      ),
                    if (!_editingCategories)
                      CategoryTile(
                        emoji: '',
                        label: 'New',
                        isNew: true,
                        onTap: () => presentSheet<void>(
                          context,
                          (_, ctl) => NewCategorySheet(store: store, income: _income, controller: ctl),
                        ),
                      ),
                  ],
                ),
              ),

              // ---- Activity ----
              if (items.isEmpty) const GroupHeader('Activity'),
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.zero,
                  child: InsetCard(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.tray, size: 34, color: AppColors.faint.of(context)),
                        const SizedBox(height: 8),
                        Text('Nothing yet. Add your first entry above.',
                            style: TextStyle(color: AppColors.muted.of(context), fontSize: 15)),
                      ],
                    ),
                  ),
                )
              else
                for (final MapEntry(key: day, value: list) in days.entries)
                  InsetSection(
                    header: _DayHeader(day: day, net: list.fold(0.0, (s, e) => s + e.signed)),
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    children: [
                      for (final e in list)
                        EntryRow(
                          key: ValueKey(e.id),
                          entry: e,
                          title: store.titleFor(e),
                          category: store.categoryFor(e),
                          onDelete: () => store.deleteEntry(e.id),
                        ),
                    ],
                  ),
              if (all.length > items.length)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: InsetCard(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onPressed: () => setState(() => _shown += _page),
                      child: const Text('Show More'),
                    ),
                  ),
                ),
              if (items.isNotEmpty) const GroupFooter('Swipe left on an entry to delete it.'),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.monthIn, required this.monthOut, required this.onTap});
  final double balance;
  final double monthIn;
  final double monthOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = balance > 0.004;
    final negative = balance < -0.004;
    final tint = positive ? AppColors.green : (negative ? AppColors.red : AppColors.muted);
    return GestureDetector(
      onTap: onTap,
      child: InsetCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Current Balance',
                    style: TextStyle(color: AppColors.muted.of(context), fontSize: 15, fontWeight: FontWeight.w500)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: tint.of(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    positive ? 'Positive' : (negative ? 'Negative' : 'Even'),
                    style: TextStyle(color: tint.of(context), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                signedEuro(balance),
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: AppColors.money(context, balance),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: AppColors.separator.of(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: CupertinoIcons.arrow_down_circle_fill,
                    color: AppColors.green,
                    title: 'In this month',
                    value: signedEuro(monthIn),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    icon: CupertinoIcons.arrow_up_circle_fill,
                    color: AppColors.red,
                    title: 'Out this month',
                    value: euro(-monthOut),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.faint.of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.title, required this.value});
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color.of(context), size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: AppColors.muted.of(context))),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.net});
  final DateTime day;
  final double net;

  @override
  Widget build(BuildContext context) => SectionHeader(dayHeading(day), trailing: Text(signedEuro(net)));
}

// ---------------------------------------------------------------------------
// Rows and tiles
// ---------------------------------------------------------------------------

class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    required this.title,
    required this.category,
    required this.onDelete,
  });
  final Entry entry;
  final String title;
  final Category category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('d-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.red.of(context),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(CupertinoIcons.trash_fill, color: CupertinoColors.white),
      ),
      confirmDismiss: (_) => confirmIos(context, 'Delete ${signedEuro(entry.signed)}?',
          message: '$title${entry.hasNote ? ' · ${entry.note!.trim()}' : ''} · ${dayHeading(entry.date)}'),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      child: CupertinoListTile(
        backgroundColor: AppColors.card.of(context),
        leadingSize: 34,
        leading: EmojiBadge(category.emoji, size: 34),
        title: Row(
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            if (entry.isRecurring) ...[
              const SizedBox(width: 5),
              Icon(CupertinoIcons.repeat, size: 13, color: AppColors.muted.of(context)),
            ],
          ],
        ),
        // The note (if any) first, then the time.
        subtitle: Text(
          [
            if (entry.hasNote) entry.note!.trim(),
            hhmm(entry.date),
            if (entry.income) 'Income',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          signedEuro(entry.signed),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: (entry.income ? AppColors.green : AppColors.label).of(context),
          ),
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
    this.isNew = false,
    this.removable = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool isNew;

  /// Edit mode: shows the red badge; a tap then deletes (after asking).
  final bool removable;

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
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: (_down ? CupertinoColors.systemGrey4 : AppColors.card).of(context),
            borderRadius: BorderRadius.circular(16),
            border: widget.removable ? Border.all(color: AppColors.red.of(context).withValues(alpha: 0.35), width: 1.5) : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isNew)
                Icon(CupertinoIcons.plus_circle_fill, size: 30, color: AppColors.blue.of(context))
              else
                Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (widget.isNew ? AppColors.blue : AppColors.label).of(context),
                  ),
                ),
              ),
            ],
          )),
              if (widget.removable)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: AppColors.red.of(context), shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.minus, size: 14, color: CupertinoColors.white),
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

/// How the balance is made up, and where you set what you started with.
class BalanceSheet extends StatefulWidget {
  const BalanceSheet({super.key, required this.store, required this.controller});
  final Store store;
  final ScrollController controller;

  @override
  State<BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<BalanceSheet> {
  late bool _negative = widget.store.startBalance < 0;
  late final _ctrl = TextEditingController(text: _fmt(widget.store.startBalance.abs()));
  String? _error;

  static String _fmt(double v) {
    if (v == 0) return '';
    final t = v.toStringAsFixed(2).replaceAll('.', ',');
    return t.endsWith(',00') ? t.substring(0, t.length - 3) : t;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _value {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return 0;
    final v = double.tryParse(text.replaceAll(',', '.'));
    if (v == null) return null;
    final rounded = (v * 100).roundToDouble() / 100;
    return _negative ? -rounded : rounded;
  }

  void _save() {
    final v = _value;
    if (v == null) {
      setState(() => _error = 'Type an amount, like 250 or 12,50.');
      return;
    }
    widget.store.setStartBalance(v);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    var inc = 0.0, out = 0.0;
    for (final e in s.entries) {
      if (e.income) {
        inc += e.amount;
      } else {
        out += e.amount;
      }
    }
    final start = _value ?? s.startBalance;
    final total = start + inc - out;
    return SheetScaffold(
      title: 'Balance',
      controller: widget.controller,
      doneLabel: 'Save',
      onDone: _save,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            children: [
              Text('Balance', style: TextStyle(color: AppColors.muted.of(context), fontSize: 15)),
              FittedBox(
                child: Text(signedEuro(total),
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: AppColors.money(context, total))),
              ),
            ],
          ),
        ),
        InsetSection(
          header: SectionHeader('How it adds up'),
          children: [
            CupertinoListTile(
              title: const Text('Starting balance'),
              additionalInfo: Text(signedEuro(start)),
            ),
            CupertinoListTile(
              title: const Text('Money in'),
              additionalInfo: Text(signedEuro(inc), style: TextStyle(color: AppColors.green.of(context))),
            ),
            CupertinoListTile(
              title: const Text('Money out'),
              additionalInfo: Text(euro(-out)),
            ),
          ],
        ),
        const GroupHeader('Starting balance'),
        Segments<bool>(
          value: _negative,
          items: const {false: 'I had money (+)', true: 'I owed money (−)'},
          onChanged: (v) => setState(() => _negative = v),
        ),
        const SizedBox(height: 10),
        InsetCard(
          child: CupertinoTextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            placeholder: '0',
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(_negative ? '− €' : '+ €',
                  style: TextStyle(
                      fontSize: 17, color: (_negative ? AppColors.red : AppColors.green).of(context))),
            ),
            decoration: null,
            padding: const EdgeInsets.fromLTRB(8, 13, 16, 13),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        GroupFooter(
          _error ?? 'What you had (or owed) before you started using Even. Everything you add goes on top of it.',
          color: _error != null ? AppColors.red : null,
        ),
      ],
    );
  }
}

class NewCategorySheet extends StatefulWidget {
  const NewCategorySheet({super.key, required this.store, required this.income, required this.controller});
  final Store store;
  final bool income;
  final ScrollController controller;

  @override
  State<NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<NewCategorySheet> {
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
    final err = widget.store.addCategory(_name.text, _emoji.text, income: widget.income);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.income ? suggestedIncomeEmojis : suggestedEmojis;
    return SheetScaffold(
      title: widget.income ? 'New Income Type' : 'New Category',
      controller: widget.controller,
      doneLabel: 'Add',
      onDone: _save,
      children: [
        InsetSection(
          children: [
            CupertinoTextField(
              controller: _emoji,
              placeholder: widget.income ? 'Emoji 💰' : 'Emoji 🏷️',
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              onChanged: (_) => setState(() {}),
            ),
            CupertinoTextField(
              controller: _name,
              autofocus: true,
              placeholder: widget.income ? 'Name, like Freelance' : 'Name, like Gym',
              maxLength: 14,
              textCapitalization: TextCapitalization.sentences,
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
        if (_error != null) GroupFooter(_error!, color: AppColors.red),
        const GroupHeader('Suggestions'),
        InsetCard(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final e in emojis)
                GestureDetector(
                  onTap: () => setState(() => _emoji.text = e),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _emoji.text == e
                          ? AppColors.blue.of(context).withValues(alpha: 0.2)
                          : AppColors.fill.of(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
