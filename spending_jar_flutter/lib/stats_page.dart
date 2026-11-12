import 'dart:math' as math;

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

        // Group by category
        final groups = <String, _Group>{};
        for (final e in items) {
          final c = store.categoryFor(e);
          final g = groups.putIfAbsent(e.category, () => _Group(c.emoji, c.label));
          g.total += e.amount;
          g.count++;
        }
        final rows = groups.values.toList()..sort((a, b) => b.total.compareTo(a.total));

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              SegmentedButton<Period>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: Period.week, label: Text('Week')),
                  ButtonSegment(value: Period.month, label: Text('Month')),
                  ButtonSegment(value: Period.year, label: Text('Year')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() {
                  _period = s.first;
                  _offset = 0;
                }),
              ),
              const SizedBox(height: 14),

              // Period navigation
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _offset--),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous',
                  ),
                  Expanded(
                    child: Text(r.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  IconButton.filledTonal(
                    onPressed: _offset < 0 ? () => setState(() => _offset++) : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Totals
              Row(
                children: [
                  Expanded(child: _StatCard(title: 'Spent', value: euro(total))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(title: 'Per day', value: euro(total / elapsed))),
                ],
              ),
              const SizedBox(height: 14),

              // Budget bar
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: AppColors.track,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(pct * 100).round()}% of ${euro(periodBudget)}${estimated ? ' estimated' : ''} budget · '
                '${diff >= 0 ? '${euro(diff)} under' : '${euro(-diff)} over'}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),

              // Chart
              const SizedBox(height: 22),
              const Text('Over time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _BarChart(buckets: r.buckets, sums: sums),

              // By category
              const SizedBox(height: 22),
              const Text('By category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text('Nothing spent in this period', style: TextStyle(color: Color(0xFF999999)))),
                )
              else
                for (final g in rows) _CategoryRow(group: g, total: total, top: rows.first.total),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF777777), fontSize: 14)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: max == 0
          ? const Center(child: Text('No spending in this period', style: TextStyle(color: Color(0xFFAAAAAA))))
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
                                  constraints: const BoxConstraints(maxWidth: 28),
                                  decoration: BoxDecoration(
                                    color: sums[i] == 0
                                        ? AppColors.track
                                        : (!now.isBefore(buckets[i].start) && now.isBefore(buckets[i].end))
                                            ? AppColors.blue
                                            : AppColors.green,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 14,
                              child: Text(buckets[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Text(group.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: group.label, style: const TextStyle(fontSize: 15)),
                  TextSpan(
                      text: ' · ${group.count}×',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ])),
              ),
              Text(euro(group.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 44,
                child: Text('${(group.total / total * 100).round()}%',
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: top > 0 ? group.total / top : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1ECE4),
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
