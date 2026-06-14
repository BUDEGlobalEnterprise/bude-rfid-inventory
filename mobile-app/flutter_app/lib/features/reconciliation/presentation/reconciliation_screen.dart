import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/sync/providers.dart';
import '../../inventory/presentation/providers/item_search_notifier.dart';
import '../domain/reconciliation_draft.dart';
import 'providers/reconciliation_providers.dart';

class ReconciliationScreen extends ConsumerWidget {
  const ReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(reconciliationDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock count')),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load warehouses: $e'),
          ),
        ),
        data: (warehouses) =>
            _Body(draft: draft, warehouses: warehouses),
      ),
      floatingActionButton: draft.lines.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: const Text('Queue count'),
              onPressed:
                  draft.isSubmittable ? () => _submit(context, ref, draft) : null,
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReconciliationDraft draft,
  ) async {
    final id = await ref.read(submitReconciliationUseCaseProvider).call(draft);
    // ignore: discarded_futures
    ref.read(syncEngineProvider).kick();
    ref.read(reconciliationDraftProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Count queued (op $id). Watch /sync for status.'),
        action: SnackBarAction(
          label: 'Open sync',
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final ReconciliationDraft draft;
  final List<String> warehouses;

  const _Body({required this.draft, required this.warehouses});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(reconciliationDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('warehouse-${widget.draft.warehouse}'),
          initialValue: widget.draft.warehouse,
          decoration: const InputDecoration(
            labelText: 'Warehouse',
            border: OutlineInputBorder(),
            helperText: 'Changing this clears the current count.',
          ),
          items: widget.warehouses
              .map((w) => DropdownMenuItem(value: w, child: Text(w)))
              .toList(),
          onChanged: notifier.setWarehouse,
        ),
        const Divider(height: 32),
        Row(
          children: [
            Text(
              'Counted items (${widget.draft.lines.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: _resolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
              onPressed: (widget.draft.warehouse == null || _resolving)
                  ? null
                  : () => _scanAndAdd(context, widget.draft.warehouse!),
            ),
          ],
        ),
        if (widget.draft.warehouse == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Pick a warehouse first.'),
          )
        else if (widget.draft.lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Scan items to start counting.'),
          )
        else
          ...widget.draft.lines.map(
            (line) => _CountTile(
              line: line,
              warehouse: widget.draft.warehouse!,
              onCountChanged: (q) => notifier.setCount(line.itemCode, q),
              onRemove: () => notifier.removeLine(line.itemCode),
            ),
          ),
      ],
    );
  }

  Future<void> _scanAndAdd(BuildContext context, String warehouse) async {
    final result = await context.push<ScanEvent>('/scan');
    if (result == null || !context.mounted) return;

    setState(() => _resolving = true);
    // Run item name lookup and expected qty prefetch concurrently.
    final useCase = ref.read(getItemByBarcodeUseCaseProvider);
    final (either, expected) = await (
      useCase(result.barcode),
      ref.read(expectedQtyProvider(BinKey(result.barcode, warehouse)).future),
    ).wait;
    if (!mounted) return;
    setState(() => _resolving = false);

    either.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (item) {
        ref.read(reconciliationDraftProvider.notifier).addLine(
              CountLine(
                itemCode: item.itemCode,
                itemName: item.itemName,
                countedQty: 1,
                expectedQty: expected,
              ),
            );
      },
    );
  }
}

class _CountTile extends ConsumerWidget {
  final CountLine line;
  final String warehouse;
  final ValueChanged<double> onCountChanged;
  final VoidCallback onRemove;

  const _CountTile({
    required this.line,
    required this.warehouse,
    required this.onCountChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final variance = line.variance;
    String? subtitle;
    Color? subtitleColor;
    if (line.itemName != null && line.expectedQty != null) {
      subtitle = '${line.itemName} · Expected ${_fmt(line.expectedQty!)} · Variance ${_fmt(variance!)}';
      if (variance > 0) {
        subtitleColor = scheme.tertiary;
      } else if (variance < 0) {
        subtitleColor = scheme.error;
      }
    } else if (line.itemName != null) {
      subtitle = line.itemName;
    } else if (line.expectedQty != null) {
      subtitle = 'Expected ${_fmt(line.expectedQty!)} · Variance ${_fmt(variance!)}';
      if (variance > 0) {
        subtitleColor = scheme.tertiary;
      } else if (variance < 0) {
        subtitleColor = scheme.error;
      }
    }
    return ListTile(
      title: Text(line.itemCode),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: subtitleColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: _fmt(line.countedQty),
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null && q >= 0) onCountChanged(q);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
