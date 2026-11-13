import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';

/// List of recurring money in and out, with Add and swipe-to-delete.
class RecurringSheet extends StatelessWidget {
  const RecurringSheet({super.key, required this.store, required this.controller});
  final Store store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = [...store.recurring]..sort((a, b) => a.next.compareTo(b.next));
        final perMonth = items.fold<double>(0, (s, r) => s + r.perMonth);
        final incomes = items.where((r) => r.income).toList();
        final costs = items.where((r) => !r.income).toList();

        Widget section(String title, List<Recurring> list) => CupertinoListSection.insetGrouped(
              header: SectionHeader(title),
              children: [
                for (final r in list)
                  Dismissible(
                    key: ValueKey('rec-${r.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.red.of(context),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 22),
                      child: const Text('Stop',
                          style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600)),
                    ),
                    confirmDismiss: (_) => confirmIos(
                      context,
                      'Stop "${r.title}"?',
                      message: 'Entries already added stay in your list.',
                      ok: 'Stop',
                    ),
                    onDismissed: (_) {
                      HapticFeedback.mediumImpact();
                      store.deleteRecurring(r.id);
                    },
                    child: CupertinoListTile(
                      backgroundColor: AppColors.card.of(context),
                      leadingSize: 34,
                      leading: EmojiBadge(r.emoji, size: 34),
                      title: Text(r.title),
                      subtitle: Text('${freqName(r.freq)} · next ${shortDate(r.next)}'),
                      trailing: Text(
                        signedEuro(r.income ? r.amount : -r.amount),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: (r.income ? AppColors.green : AppColors.label).of(context),
                        ),
                      ),
                    ),
                  ),
              ],
            );

        return SheetScaffold(
          title: 'Recurring',
          controller: controller,
          showCancel: false,
          children: [
            if (incomes.isNotEmpty) section('Money in', incomes),
            if (costs.isNotEmpty) section('Money out', costs),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  leading: Icon(CupertinoIcons.plus_circle_fill, color: AppColors.blue.of(context), size: 26),
                  title: Text('Add Recurring', style: TextStyle(color: AppColors.blue.of(context))),
                  onTap: () => presentSheet<void>(context, (_, c) => _AddRecurringSheet(store: store, controller: c)),
                ),
              ],
            ),
            GroupFooter(
              items.isEmpty
                  ? 'Add things that happen regularly: your salary, rent, the gym or Netflix. '
                      'They are added to your balance automatically on each date.'
                  : 'Together about ${signedEuro(perMonth)} a month. Swipe left to stop one.',
            ),
          ],
        );
      },
    );
  }
}

class _AddRecurringSheet extends StatefulWidget {
  const _AddRecurringSheet({required this.store, required this.controller});
  final Store store;
  final ScrollController controller;

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  bool _income = false;
  String? _categoryKey;
  Period _freq = Period.month;
  DateTime _start = dayStart(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<Category> get _cats => widget.store.categoriesOf(income: _income);

  Category get _category {
    final list = _cats;
    for (final c in list) {
      if (c.key == _categoryKey) return c;
    }
    return list.isNotEmpty
        ? list.first
        : (_income ? defaultIncomeCategories.last : defaultCategories.last);
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter an amount, like 9,99.');
      return;
    }
    widget.store.addRecurring(name: _name.text, amount: amount, category: _category, freq: _freq, start: _start);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _category;
    return SheetScaffold(
      title: 'New Recurring',
      controller: widget.controller,
      doneLabel: 'Add',
      onDone: _save,
      children: [
        const SizedBox(height: 8),
        Segments<bool>(
          value: _income,
          items: const {false: 'Spending', true: 'Income'},
          onChanged: (v) => setState(() {
            _income = v;
            _categoryKey = null;
          }),
        ),
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoTextField(
              controller: _name,
              placeholder: _income ? 'Name, like Salary' : 'Name, like Rent or Netflix',
              textCapitalization: TextCapitalization.sentences,
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
            CupertinoTextField(
              controller: _amount,
              placeholder: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              prefix: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(_income ? '+ €' : '− €',
                    style: TextStyle(color: (_income ? AppColors.green : AppColors.muted).of(context))),
              ),
              decoration: null,
              padding: const EdgeInsets.fromLTRB(8, 13, 16, 13),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
        if (_error != null) GroupFooter(_error!, color: AppColors.red),

        const GroupHeader('Repeats'),
        Segments<Period>(
          value: _freq,
          items: const {Period.week: 'Weekly', Period.month: 'Monthly', Period.year: 'Yearly'},
          onChanged: (p) => setState(() => _freq = p),
        ),

        GroupHeader(_income ? 'Source' : 'Category'),
        InsetCard(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _cats)
                GestureDetector(
                  onTap: () => setState(() => _categoryKey = c.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (c.key == selected.key ? AppColors.blue : AppColors.fill).of(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${c.emoji} ${c.label}',
                      style: TextStyle(
                        fontSize: 15,
                        color: c.key == selected.key ? CupertinoColors.white : AppColors.label.of(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const GroupHeader('First date'),
        InsetCard(
          child: SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _start,
              minimumDate: DateTime(2000),
              maximumDate: DateTime(2100),
              onDateTimeChanged: (d) => setState(() => _start = dayStart(d)),
            ),
          ),
        ),
        GroupFooter(
          _start.isAfter(dayStart(DateTime.now()))
              ? 'It will be added for the first time on ${shortDate(_start)}.'
              : 'Everything from ${shortDate(_start)} until today is added straight away.',
        ),
      ],
    );
  }
}
