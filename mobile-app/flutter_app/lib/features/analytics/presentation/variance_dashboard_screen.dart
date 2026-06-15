import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/utils/locale_ext.dart';
import '../../warehouse/presentation/providers/warehouse_providers.dart';
import '../domain/entities/reconciliation_summary.dart';
import 'providers/analytics_providers.dart';

class VarianceDashboardScreen extends ConsumerStatefulWidget {
  const VarianceDashboardScreen({super.key});

  @override
  ConsumerState<VarianceDashboardScreen> createState() =>
      _VarianceDashboardScreenState();
}

class _VarianceDashboardScreenState
    extends ConsumerState<VarianceDashboardScreen> {
  String? _warehouse;
  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final historyAsync = ref.watch(reconciliationHistoryProvider(_warehouse));
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reconciliationHistory)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: warehousesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (warehouses) => DropdownButtonFormField<String>(
                initialValue: _warehouse,
                decoration: InputDecoration(
                  labelText: '${l10n.warehouse} (${l10n.noneSelected})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.noneSelected),
                  ),
                  ...warehouses.map(
                    (w) => DropdownMenuItem(value: w, child: Text(w)),
                  ),
                ],
                onChanged: (w) => setState(() => _warehouse = w),
              ),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const ShimmerList(count: 6),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center),
                ),
              ),
              data: (summaries) => summaries.isEmpty
                  ? EmptyStateView(
                      icon: Icons.balance,
                      title: l10n.noReconciliations,
                      subtitle: l10n.noReconciliationsSubtitle,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(
                        reconciliationHistoryProvider(_warehouse),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: summaries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, i) => _ReconCard(
                          summary: summaries[i],
                          dateFmt: _dateFmt,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconCard extends StatelessWidget {
  final ReconciliationSummary summary;
  final DateFormat dateFmt;

  const _ReconCard({required this.summary, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final surplus = summary.surplusCount;
    final deficit = summary.deficitCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          summary.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${dateFmt.format(summary.postingDate)}'
          '${summary.warehouse != null ? " · ${summary.warehouse}" : ""}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (surplus > 0)
              _Chip(label: '+$surplus', color: Colors.green.shade700),
            if (surplus > 0 && deficit > 0) const SizedBox(width: 4),
            if (deficit > 0)
              _Chip(label: '-$deficit', color: scheme.error),
            if (surplus == 0 && deficit == 0)
              _Chip(label: l10n.counted, color: scheme.onSurfaceVariant),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
        children: summary.items
            .map((line) => _VarianceLineTile(line: line))
            .toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VarianceLineTile extends StatelessWidget {
  final VarianceLine line;
  const _VarianceLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final v = line.variance;
    final Color varColor;
    final String varLabel;
    if (v > 0) {
      varColor = Colors.green.shade700;
      varLabel = '+${_fmt(v)}';
    } else if (v < 0) {
      varColor = scheme.error;
      varLabel = _fmt(v);
    } else {
      varColor = scheme.onSurfaceVariant;
      varLabel = '0';
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(line.itemName ?? line.itemCode, style: const TextStyle(fontSize: 13)),
      subtitle: line.itemName != null
          ? Text(line.itemCode, style: const TextStyle(fontSize: 11))
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${l10n.counted}: ${_fmt(line.countedQty)}  ${l10n.expected}: ${_fmt(line.expectedQty)}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          Text(
            varLabel,
            style: TextStyle(
              fontSize: 13,
              color: varColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
