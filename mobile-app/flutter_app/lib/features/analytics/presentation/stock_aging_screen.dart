import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/utils/locale_ext.dart';
import '../../warehouse/presentation/providers/warehouse_providers.dart';
import '../domain/entities/stock_aging_row.dart';
import 'providers/analytics_providers.dart';

class StockAgingScreen extends ConsumerStatefulWidget {
  const StockAgingScreen({super.key});

  @override
  ConsumerState<StockAgingScreen> createState() => _StockAgingScreenState();
}

class _StockAgingScreenState extends ConsumerState<StockAgingScreen> {
  String? _warehouse;
  int _thresholdDays = 30;

  static const _thresholds = [7, 14, 30, 60, 90];
  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stockAging)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: warehousesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (warehouses) => DropdownButtonFormField<String>(
                initialValue: _warehouse,
                decoration: InputDecoration(
                  labelText: l10n.warehouse,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: warehouses
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (w) => setState(() => _warehouse = w),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  l10n.thresholdDays,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      segments: _thresholds
                          .map(
                            (d) => ButtonSegment(
                              value: d,
                              label: Text('$d'),
                            ),
                          )
                          .toList(),
                      selected: {_thresholdDays},
                      onSelectionChanged: (s) =>
                          setState(() => _thresholdDays = s.first,),
                      showSelectedIcon: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _warehouse == null
                ? Center(child: Text(l10n.pickWarehouseFirst))
                : _AgingList(
                    warehouse: _warehouse!,
                    thresholdDays: _thresholdDays,
                    dateFmt: _dateFmt,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgingList extends ConsumerWidget {
  final String warehouse;
  final int thresholdDays;
  final DateFormat dateFmt;

  const _AgingList({
    required this.warehouse,
    required this.thresholdDays,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (warehouse: warehouse, thresholdDays: thresholdDays);
    final agingAsync = ref.watch(stockAgingProvider(key));

    return agingAsync.when(
      loading: () => const ShimmerList(count: 8),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString(), textAlign: TextAlign.center),
        ),
      ),
      data: (rows) => rows.isEmpty
          ? EmptyStateView(
              icon: Icons.check_circle_outline,
              title: l10n.noIdleItems,
              subtitle: l10n.noIdleItemsSubtitle,
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(stockAgingProvider(key)),
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) =>
                    _AgingTile(row: rows[i], dateFmt: dateFmt),
              ),
            ),
    );
  }
}

class _AgingTile extends StatelessWidget {
  final StockAgingRow row;
  final DateFormat dateFmt;

  const _AgingTile({required this.row, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = row.daysIdle;
    final Color avatarColor;
    if (days == null) {
      avatarColor = Colors.grey;
    } else if (days >= 60) {
      avatarColor = Colors.red;
    } else {
      avatarColor = Colors.amber.shade700;
    }

    final String dateLabel = row.lastMovementDate != null
        ? l10n.lastMovedDate(dateFmt.format(row.lastMovementDate!))
        : l10n.neverMoved;

    final String qtyLabel =
        '${l10n.actualQty}: ${_fmt(row.actualQty)} · $dateLabel';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: avatarColor.withValues(alpha: 0.15),
        child: Text(
          days != null ? '$days' : '∞',
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(row.itemName ?? row.itemCode),
      subtitle: Text(
        row.itemName != null ? '${row.itemCode} · $qtyLabel' : qtyLabel,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: days != null
          ? Text(
              l10n.daysIdle(days),
              style: TextStyle(
                fontSize: 11,
                color: avatarColor,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
