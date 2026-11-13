import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import 'main.dart';
import 'models.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.store});
  final Store store;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Period _period = Period.month;
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final r = rangeFor(_period, _offset);
        final t = store.totalsIn(r.start, r.end);
        final net = t.inc - t.out;
        final now = DateTime.now();
        final endBalance = store.balanceAt(r.end.isAfter(now) ? now.add(const Duration(seconds: 1)) : r.end);
        final startBalance = store.balanceAt(r.start);

        final sums = [for (final b in r.buckets) store.totalsIn(b.start, b.end)];

        final spend = <String, _Group>{};
        final earn = <String, _Group>{};
        for (final e in store.between(r.start, r.end)) {
          final c = store.categoryFor(e);
          final g = (e.income ? earn : spend).putIfAbsent(e.category, () => _Group(c.emoji, c.label));
          g.total += e.amount;
          g.count++;
        }
        final spendRows = spend.values.toList()..sort((a, b) => b.total.compareTo(a.total));
        final earnRows = earn.values.toList()..sort((a, b) => b.total.compareTo(a.total));

        return LargeTitlePage(
          title: 'Stats',
          children: [
            const SizedBox(height: 4),
            Segments<Period>(
              value: _period,
              items: const {Period.week: 'Week', Period.month: 'Month', Period.year: 'Year'},
              onChanged: (p) => setState(() {
                _period = p;
                _offset = 0;
              }),
            ),
            const SizedBox(height: 6),

            // Period navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
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
            ),

            // Net for the period, big
            InsetCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(net >= 0 ? 'You saved' : 'You spent more than you earned',
                      style: TextStyle(fontSize: 15, color: AppColors.muted.of(context))),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(signedEuro(net),
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: AppColors.money(context, net))),
                  ),
                  const SizedBox(height: 12),
                  _SplitBar(inc: t.inc, out: t.out),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Dot(color: AppColors.green.of(context)),
                      Text(' In ${signedEuro(t.inc)}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 14),
                      _Dot(color: AppColors.red.of(context)),
                      Text(' Out ${euro(-t.out)}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            const GroupHeader('Over time'),
            _NetChart(buckets: r.buckets, sums: sums),

            CupertinoListSection.insetGrouped(
              header: SectionHeader('Balance'),
              children: [
                CupertinoListTile(
                  title: const Text('At the start'),
                  additionalInfo: Text(signedEuro(startBalance),
                      style: TextStyle(color: AppColors.money(context, startBalance))),
                ),
                CupertinoListTile(
                  title: Text(_offset == 0 ? 'Now' : 'At the end'),
                  additionalInfo:
                      Text(signedEuro(endBalance), style: TextStyle(color: AppColors.money(context, endBalance))),
                ),
              ],
            ),

            if (spendRows.isEmpty && earnRows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: InsetCard(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('Nothing in this period',
                        style: TextStyle(color: AppColors.muted.of(context), fontSize: 15)),
                  ),
                ),
              ),
            if (spendRows.isNotEmpty)
              CupertinoListSection.insetGrouped(
                header: SectionHeader('Spending by category'),
                children: [
                  for (final g in spendRows)
                    _CategoryRow(group: g, total: t.out, top: spendRows.first.total, color: AppColors.red),
                ],
              ),
            if (earnRows.isNotEmpty)
              CupertinoListSection.insetGrouped(
                header: SectionHeader('Income by source'),
                children: [
                  for (final g in earnRows)
                    _CategoryRow(group: g, total: t.inc, top: earnRows.first.total, color: AppColors.green),
                ],
              ),
          ],
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

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// One bar split into green (in) and red (out).
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.inc, required this.out});
  final double inc;
  final double out;

  @override
  Widget build(BuildContext context) {
    final total = inc + out;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: total == 0
            ? Container(color: AppColors.track.of(context))
            : Row(
                children: [
                  if (inc > 0) Expanded(flex: (inc / total * 1000).round(), child: Container(color: AppColors.green.of(context))),
                  if (inc > 0 && out > 0) const SizedBox(width: 2),
                  if (out > 0) Expanded(flex: (out / total * 1000).round(), child: Container(color: AppColors.red.of(context))),
                ],
              ),
      ),
    );
  }
}

/// Bars above the line for money in, below for money out.
class _NetChart extends StatelessWidget {
  const _NetChart({required this.buckets, required this.sums});
  final List<Bucket> buckets;
  final List<({double inc, double out})> sums;

  @override
  Widget build(BuildContext context) {
    final maxIn = sums.fold<double>(0, (m, s) => math.max(m, s.inc));
    final maxOut = sums.fold<double>(0, (m, s) => math.max(m, s.out));
    final max = math.max(maxIn, maxOut);
    final now = DateTime.now();
    const chartH = 170.0;
    // Share of the height above the line, so a month with little income still has room.
    final upShare = max == 0 ? 0.5 : (maxIn == 0 ? 0.0 : (maxOut == 0 ? 1.0 : maxIn / (maxIn + maxOut)));
    final upH = (chartH * upShare).clamp(chartH * 0.2, chartH * 0.8);
    final downH = chartH - upH;
    final scale = max == 0 ? 0.0 : math.min(upH / (maxIn == 0 ? 1 : maxIn), downH / (maxOut == 0 ? 1 : maxOut));

    return InsetCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: max == 0
          ? SizedBox(
              height: chartH,
              child: Center(
                child: Text('Nothing in this period',
                    style: TextStyle(color: AppColors.muted.of(context), fontSize: 15)),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: chartH,
                  child: Row(
                    children: [
                      for (var i = 0; i < buckets.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: buckets.length > 12 ? 1 : 3),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: upH,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: _bar(context, sums[i].inc * scale, AppColors.green, true,
                                        !now.isBefore(buckets[i].start) && now.isBefore(buckets[i].end)),
                                  ),
                                ),
                                Container(height: 1, color: AppColors.separator.of(context)),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: _bar(context, sums[i].out * scale, AppColors.red, false,
                                        !now.isBefore(buckets[i].start) && now.isBefore(buckets[i].end)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (final b in buckets)
                      Expanded(
                        child: Text(b.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.muted.of(context))),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _bar(BuildContext context, double h, Color color, bool up, bool current) {
    if (h <= 0) return const SizedBox.shrink();
    final c = color.of(context);
    return Container(
      height: math.max(h, 2),
      constraints: const BoxConstraints(maxWidth: 24),
      decoration: BoxDecoration(
        color: current ? c : c.withValues(alpha: 0.75),
        borderRadius: up
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.group, required this.total, required this.top, required this.color});
  final _Group group;
  final double total;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          EmojiBadge(group.emoji, size: 34),
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
                            text: '  ${group.count}×',
                            style: TextStyle(fontSize: 13, color: AppColors.muted.of(context))),
                      ])),
                    ),
                    Text(euro(group.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 6,
                          color: AppColors.track.of(context),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: top > 0 ? (group.total / top).clamp(0.0, 1.0) : 0,
                            child: Container(color: color.of(context)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text('${total > 0 ? (group.total / total * 100).round() : 0}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 13, color: AppColors.muted.of(context))),
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
