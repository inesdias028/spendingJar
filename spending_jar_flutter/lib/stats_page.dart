import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'main.dart';
import 'models.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.store});
  final Store store;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Period _period = Period.week;
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final r = rangeFor(_period, _offset);
        final items = store.between(r.start, r.end);
        final total = items.fold<double>(0, (s, e) => s + e.amount);

        // For the current period, average only over the days so far.
        final now = DateTime.now();
        final elapsed = _offset == 0
            ? math.max(1, DateTime.utc(now.year, now.month, now.day)
                    .difference(DateTime.utc(r.start.year, r.start.month, r.start.day))
                    .inDays +
                1)
            : r.days;
        final periodBudget = store.budgetFor(_period, r.days);
        final estimated = !store.isSet(_period);
        final pct = periodBudget > 0 ? total / periodBudget : 0.0;
        final diff = periodBudget - total;
        final barColor = pct < 0.8 ? AppColors.green : (pct <= 1 ? AppColors.orange : AppColors.red);

        final sums = [
          for (final b in r.buckets)
            items
                .where((e) => !e.date.isBefore(b.start) && e.date.isBefore(b.end))
                .fold<double>(0, (s, e) => s + e.amount),
        ];

        final groups = <String, _Group>{};
        for (final e in items) {
          final c = store.categoryFor(e);
          final g = groups.putIfAbsent(e.category, () => _Group(c.emoji, c.label));
          g.total += e.amount;
          g.count++;
        }
        final rows = groups.values.toList()..sort((a, b) => b.total.compareTo(a.total));

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const LargeTitle('Stats'),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<Period>(
                  groupValue: _period,
                  children: const {
                    Period.week: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Week')),
                    Period.month: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Month')),
                    Period.year: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Year')),
                  },
                  onValueChanged: (p) {
                    if (p != null) {
                      setState(() {
                        _period = p;
                        _offset = 0;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Period navigation
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => setState(() => _offset--),
                    child: const Icon(CupertinoIcons.chevron_left, size: 22),
                  ),
                  Expanded(
                    child: Text(r.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: _offset < 0 ? () => setState(() => _offset++) : null,
                    child: const Icon(CupertinoIcons.chevron_right, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Totals
              Row(
                children: [
                  Expanded(child: _StatCard(title: 'Spent', value: euro(total))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(title: 'Per day', value: euro(total / elapsed))),
                ],
              ),
              const SizedBox(height: 10),

              // Budget
              InsetCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${estimated ? 'Estimated budget' : 'Budget'} ${euro(periodBudget)}',
                              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                        ),
                        Text('${(pct * 100).round()}%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Bar(value: pct, color: barColor, height: 8),
                    const SizedBox(height: 8),
                    Text(
                      diff >= 0 ? '${euro(diff)} under budget' : '${euro(-diff)} over budget',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: diff >= 0 ? AppColors.darkGreen : AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),

              const GroupHeader('Over time'),
              _BarChart(buckets: r.buckets, sums: sums),

              const GroupHeader('By category'),
              if (rows.isEmpty)
                const InsetCard(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('Nothing spent in this period', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                  ),
                )
              else
                InsetCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 62),
                        _CategoryRow(group: rows[i], total: total, top: rows.first.total),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Group {
  _Group(this.emoji, this.label);
  final String emoji;
  final String label;
  double total = 0;
  int count = 0;
}

/// Simple rounded progress bar. [value] is 0..1 (anything above 1 shows full).
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, this.height = 6});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: AppColors.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InsetCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.buckets, required this.sums});
  final List<Bucket> buckets;
  final List<double> sums;

  @override
  Widget build(BuildContext context) {
    final max = sums.fold<double>(0, math.max);
    final now = DateTime.now();
    return InsetCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: SizedBox(
        height: 170,
        child: max == 0
            ? const Center(child: Text('No spending in this period', style: TextStyle(color: AppColors.muted, fontSize: 15)))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < buckets.length; i++)
                    Expanded(
                      child: Tooltip(
                        message: euro(sums[i]),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: buckets.length > 12 ? 1 : 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: sums[i] == 0 ? 0.02 : sums[i] / max,
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 26),
                                    decoration: BoxDecoration(
                                      color: sums[i] == 0
                                          ? AppColors.track
                                          : (!now.isBefore(buckets[i].start) && now.isBefore(buckets[i].end))
                                              ? AppColors.blue
                                              : AppColors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                height: 14,
                                child: Text(buckets[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    softWrap: false,
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.group, required this.total, required this.top});
  final _Group group;
  final double total;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
            child: Text(group.emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: group.label, style: const TextStyle(fontSize: 17)),
                        TextSpan(
                            text: '  ${group.count}×', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ])),
                    ),
                    Text(euro(group.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _Bar(value: top > 0 ? group.total / top : 0, color: AppColors.orange)),
                    SizedBox(
                      width: 42,
                      child: Text('${(group.total / total * 100).round()}%',
                          textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
