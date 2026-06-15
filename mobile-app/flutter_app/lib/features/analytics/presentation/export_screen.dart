import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/locale_ext.dart';
import '../../inventory/presentation/providers/item_search_notifier.dart';
import '../../warehouse/presentation/providers/warehouse_providers.dart';

enum _ExportType { warehouseStock, itemLedger }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _ExportType _type = _ExportType.warehouseStock;
  String? _warehouse;
  String _itemCode = '';
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportData)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.exportType,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_ExportType>(
            segments: [
              ButtonSegment(
                value: _ExportType.warehouseStock,
                label: Text(l10n.warehouseStock),
                icon: const Icon(Icons.warehouse_outlined),
              ),
              ButtonSegment(
                value: _ExportType.itemLedger,
                label: Text(l10n.itemLedger),
                icon: const Icon(Icons.history),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first,),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          if (_type == _ExportType.warehouseStock)
            warehousesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (warehouses) => DropdownButtonFormField<String>(
                initialValue: _warehouse,
                decoration: InputDecoration(
                  labelText: l10n.warehouse,
                  border: const OutlineInputBorder(),
                ),
                items: warehouses
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (w) => setState(() => _warehouse = w),
              ),
            )
          else
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Item code',
                border: OutlineInputBorder(),
                hintText: 'ITEM-001',
              ),
              onChanged: (v) => setState(() => _itemCode = v.trim()),
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_exporting ? l10n.exporting : l10n.exportCsv),
            onPressed: _exporting ? null : () => _export(context),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final l10n = context.l10n;
    setState(() => _exporting = true);

    try {
      final List<List<dynamic>> rows;

      if (_type == _ExportType.warehouseStock) {
        if (_warehouse == null) {
          _showSnack(context, l10n.pickWarehouseFirst);
          return;
        }
        final stockAsync =
            await ref.read(warehouseStockProvider(_warehouse!).future);
        rows = [
          [
            'Item Code', 'Item Name', 'Actual Qty', 'Reserved Qty',
            'Ordered Qty', 'Projected Qty', 'UOM',
          ],
          ...stockAsync.map((s) => [
                s.itemCode,
                s.itemName ?? '',
                s.actualQty,
                s.reservedQty,
                s.orderedQty,
                s.projectedQty,
                s.stockUom ?? '',
              ],),
        ];
      } else {
        if (_itemCode.isEmpty) {
          _showSnack(context, 'Enter an item code first.');
          return;
        }
        final repo = ref.read(itemRepositoryProvider);
        final result = await repo.getLedger(_itemCode);
        final entries = result.fold((f) => throw f, (d) => d);
        rows = [
          [
            'Date', 'Time', 'Voucher Type', 'Voucher No', 'Warehouse',
            'Qty Change', 'Balance After', 'Valuation Rate',
          ],
          ...entries.map((e) => [
                e.postingDate.toIso8601String().substring(0, 10),
                e.postingTime ?? '',
                e.voucherType,
                e.voucherNo,
                e.warehouse,
                e.actualQty,
                e.qtyAfterTransaction,
                e.valuationRate ?? '',
              ],),
        ];
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/bude_export_$ts.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Bude Export',
      );

      if (context.mounted) _showSnack(context, l10n.exportComplete);
    } catch (e) {
      if (context.mounted) _showSnack(context, '${l10n.exportFailed}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
