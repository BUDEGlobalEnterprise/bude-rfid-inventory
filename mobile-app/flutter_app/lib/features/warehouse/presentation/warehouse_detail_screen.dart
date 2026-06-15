import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/utils/locale_ext.dart';
import '../domain/entities/warehouse_stock_line.dart';
import 'providers/warehouse_providers.dart';

class WarehouseDetailScreen extends ConsumerWidget {
  final String warehouseName;
  const WarehouseDetailScreen({super.key, required this.warehouseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(warehouseStockProvider(warehouseName));

    return Scaffold(
      appBar: AppBar(title: Text(warehouseName)),
      body: stockAsync.when(
        loading: () => const ShimmerList(count: 12),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (lines) {
          if (lines.isEmpty) {
            return EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: context.l10n.noStockInWarehouse,
              subtitle: context.l10n.noStockInWarehouseSubtitle,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(warehouseStockProvider(warehouseName)),
            child: Column(
              children: [
                _StockSummaryBar(count: lines.length),
                Expanded(
                  child: ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) =>
                        _StockLineTile(line: lines[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StockSummaryBar extends StatelessWidget {
  final int count;
  const _StockSummaryBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.totalItems(count),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _StockLineTile extends StatelessWidget {
  final WarehouseStockLine line;
  const _StockLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uom = line.stockUom ?? '';
    return ListTile(
      title: Text(line.itemCode),
      subtitle: line.itemName != null ? Text(line.itemName!) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${l10n.actualQty}: ${_fmt(line.actualQty)} $uom',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '${l10n.reservedQty}: ${_fmt(line.reservedQty)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
