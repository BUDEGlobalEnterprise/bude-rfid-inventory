import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/locale_ext.dart';
import '../domain/entities/throughput_data.dart';
import 'providers/analytics_providers.dart';

class ThroughputScreen extends ConsumerStatefulWidget {
  const ThroughputScreen({super.key});

  @override
  ConsumerState<ThroughputScreen> createState() => _ThroughputScreenState();
}

class _ThroughputScreenState extends ConsumerState<ThroughputScreen> {
  int _periodDays = 7;
  static final _dateFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final throughputAsync = ref.watch(throughputProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.operationThroughput)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(l10n.last7Days)),
                ButtonSegment(value: 14, label: Text(l10n.last14Days)),
                ButtonSegment(value: 30, label: Text(l10n.last30Days)),
              ],
              selected: {_periodDays},
              onSelectionChanged: (s) =>
                  setState(() => _periodDays = s.first,),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: throughputAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (data) {
                final filtered = _filter(data, _periodDays);
                if (filtered.buckets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 56,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noOpsYet,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            l10n.noOpsYetSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryRow(data: filtered),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _ThroughputChart(
                        buckets: filtered.buckets,
                        dateFmt: _dateFmt,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...filtered.buckets.map(
                      (b) => _DayRow(bucket: b, dateFmt: _dateFmt),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ThroughputData _filter(ThroughputData data, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final buckets = data.buckets
        .where((b) => b.date.isAfter(cutoff))
        .toList();
    if (buckets.isEmpty) {
      return const ThroughputData(
        buckets: [],
        totalOps: 0,
        successRate: 0,
        mostActiveDay: null,
      );
    }
    final total = buckets.fold(0, (s, b) => s + b.totalCount);
    DateTime? mostActive;
    int maxOps = 0;
    for (final b in buckets) {
      if (b.totalCount > maxOps) {
        maxOps = b.totalCount;
        mostActive = b.date;
      }
    }
    return ThroughputData(
      buckets: buckets,
      totalOps: total,
      successRate: data.successRate,
      mostActiveDay: mostActive,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final ThroughputData data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pct = (data.successRate * 100).toStringAsFixed(0);
    final dayLabel = data.mostActiveDay != null
        ? DateFormat('d MMM').format(data.mostActiveDay!)
        : '—';
    return Row(
      children: [
        Expanded(child: _StatCard(label: l10n.totalOps, value: '${data.totalOps}')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: l10n.successRate, value: '$pct%')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: l10n.mostActiveDay, value: dayLabel)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ThroughputChart extends StatelessWidget {
  final List<DayBucket> buckets;
  final DateFormat dateFmt;
  const _ThroughputChart({required this.buckets, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    // Reverse so oldest is on left.
    final ordered = buckets.reversed.toList();

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < ordered.length; i++) {
      final b = ordered[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: b.totalCount.toDouble(),
              width: 10,
              borderRadius: BorderRadius.circular(3),
              rodStackItems: [
                BarChartRodStackItem(
                  0,
                  b.transferCount.toDouble(),
                  Colors.blue.shade400,
                ),
                BarChartRodStackItem(
                  b.transferCount.toDouble(),
                  (b.transferCount + b.receiptCount).toDouble(),
                  Colors.green.shade400,
                ),
                BarChartRodStackItem(
                  (b.transferCount + b.receiptCount).toDouble(),
                  b.totalCount.toDouble(),
                  Colors.amber.shade600,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: const FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 1,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= ordered.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFmt.format(ordered[i].date),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(enabled: true),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DayBucket bucket;
  final DateFormat dateFmt;
  const _DayRow({required this.bucket, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              dateFmt.format(bucket.date),
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          _CountBadge(bucket.transferCount, Colors.blue.shade400, 'T'),
          _CountBadge(bucket.receiptCount, Colors.green.shade400, 'R'),
          _CountBadge(bucket.reconcileCount, Colors.amber.shade600, 'C'),
          if (bucket.failedCount > 0)
            _CountBadge(bucket.failedCount, scheme.error, '!'),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _CountBadge(this.count, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
