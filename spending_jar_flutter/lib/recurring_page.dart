import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';

String freqName(Period p) => switch (p) {
      Period.week => 'Weekly',
      Period.month => 'Monthly',
      Period.year => 'Yearly',
    };

String shortDate(DateTime d) => '${d.day} ${monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// List of recurring spending, with Add and swipe-to-delete.
class RecurringSheet extends StatelessWidget {
  const RecurringSheet({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = [...store.recurring]..sort((a, b) => a.next.compareTo(b.next));
        final perMonth = items.fold<double>(
          0,
          (s, r) => s + r.amount * (r.freq == Period.week ? 52 / 12 : r.freq == Period.month ? 1 : 1 / 12),
        );
        return IosSheet(
          title: 'Recurring',
          doneLabel: 'Done',
          onDone: () => Navigator.pop(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsetCard(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const RowDivider(indent: 62),
                      Dismissible(
                        key: ValueKey('rec-${items[i].id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        confirmDismiss: (_) => confirmIos(
                          context,
                          'Stop "${items[i].name.isEmpty ? items[i].label : items[i].name}"?',
                          message: 'Spending already added stays in your list.',
                          ok: 'Stop',
                        ),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          store.deleteRecurring(items[i].id);
                        },
                        child: _RecurringRow(item: items[i]),
                      ),
                    ],
                    if (items.isNotEmpty) const RowDivider(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showCupertinoModalPopup<void>(
                        context: context,
                        builder: (_) => _AddRecurringSheet(store: store),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.add_circled_solid, color: AppColors.blue, size: 24),
                            SizedBox(width: 12),
                            Text('Add recurring spending', style: TextStyle(fontSize: 17, color: AppColors.blue)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  items.isEmpty
                      ? 'Add things you pay regularly, like rent, the gym or Netflix. They are added to your spending automatically on each date.'
                      : 'About ${euro(perMonth)} a month in total. Swipe left to stop one.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.item});
  final Recurring item;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
            child: Text(item.emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name.isEmpty ? item.label : item.name, style: const TextStyle(fontSize: 17)),
                Text('${freqName(item.freq)} · next ${shortDate(item.next)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          Text(euro(item.amount), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AddRecurringSheet extends StatefulWidget {
  const _AddRecurringSheet({required this.store});
  final Store store;

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late String _categoryKey = widget.store.categories.isNotEmpty ? widget.store.categories.first.key : '';
  Period _freq = Period.month;
  DateTime _start = dayStart(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter an amount, like 9,99.');
      return;
    }
    final cats = widget.store.categories;
    final cat = cats.where((c) => c.key == _categoryKey).isNotEmpty
        ? cats.firstWhere((c) => c.key == _categoryKey)
        : const Category(key: 'other', label: 'Other', emoji: '📦');
    widget.store.addRecurring(name: _name.text, amount: amount, category: cat, freq: _freq, start: _start);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.categories;
    return IosSheet(
      title: 'New Recurring',
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
                    controller: _name,
                    placeholder: 'Name, like Rent or Netflix',
                    textCapitalization: TextCapitalization.sentences,
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _amount,
                    placeholder: 'Amount',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    prefix: const Text('€ ', style: TextStyle(fontSize: 17, color: AppColors.muted)),
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    style: const TextStyle(fontSize: 17),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
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

          const GroupHeader('Repeats'),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<Period>(
              groupValue: _freq,
              children: const {
                Period.week: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Weekly')),
                Period.month: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Monthly')),
                Period.year: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Yearly')),
              },
              onValueChanged: (p) {
                if (p != null) setState(() => _freq = p);
              },
            ),
          ),

          const GroupHeader('Category'),
          InsetCard(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  GestureDetector(
                    onTap: () => setState(() => _categoryKey = c.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.key == _categoryKey ? AppColors.blue : AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${c.emoji} ${c.label}',
                        style: TextStyle(
                          fontSize: 15,
                          color: c.key == _categoryKey ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const GroupHeader('First payment'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _start.isAfter(dayStart(DateTime.now()))
                  ? 'It will be added for the first time on ${shortDate(_start)}.'
                  : 'Payments from ${shortDate(_start)} until today are added straight away.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
