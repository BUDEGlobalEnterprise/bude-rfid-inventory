import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/sync/providers.dart';
import '../domain/transfer_draft.dart';
import 'providers/transfer_providers.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(transferDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock transfer')),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: 'Failed to load warehouses: $e'),
        data: (warehouses) => _TransferBody(
          draft: draft,
          warehouses: warehouses,
        ),
      ),
      floatingActionButton: draft.lines.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: const Text('Queue transfer'),
              onPressed: draft.isSubmittable
                  ? () => _submit(context, ref, draft)
                  : null,
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    TransferDraft draft,
  ) async {
    final id = await ref.read(submitTransferUseCaseProvider).call(draft);
    // Kick the engine in case we're online — otherwise it'll be drained on
    // the next connectivity change or 30s tick.
    unawaited(ref.read(syncEngineProvider).kick());
    ref.read(transferDraftProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transfer queued (op $id). Watch /sync for status.'),
        action: SnackBarAction(
          label: 'Open sync',
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
  }
}

void unawaited(Future<void> _) {}

class _TransferBody extends ConsumerWidget {
  final TransferDraft draft;
  final List<String> warehouses;
  const _TransferBody({required this.draft, required this.warehouses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transferDraftProvider.notifier);
    final sameWarehouseError = draft.sourceWarehouse != null &&
        draft.sourceWarehouse == draft.targetWarehouse;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WarehouseDropdown(
          label: 'Source warehouse',
          value: draft.sourceWarehouse,
          options: warehouses,
          onChanged: notifier.setSource,
        ),
        const SizedBox(height: 12),
        _WarehouseDropdown(
          label: 'Target warehouse',
          value: draft.targetWarehouse,
          options: warehouses,
          onChanged: notifier.setTarget,
        ),
        if (sameWarehouseError) ...[
          const SizedBox(height: 8),
          Text(
            'Source and target must differ.',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
        const Divider(height: 32),
        Row(
          children: [
            Text(
              'Items (${draft.lines.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to add'),
              onPressed: () => _scanAndAdd(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (draft.lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No items yet — scan or add manually.'),
          )
        else
          ...draft.lines.map(
            (line) => _LineTile(
              line: line,
              onQtyChanged: (q) => notifier.updateQty(line.itemCode, q),
              onRemove: () => notifier.removeLine(line.itemCode),
            ),
          ),
      ],
    );
  }

  Future<void> _scanAndAdd(BuildContext context, WidgetRef ref) async {
    final result = await context.push<ScanEvent>('/scan');
    if (result == null || !context.mounted) return;
    // For now we trust the scanned code is an item_code. A future slice can
    // call bude_api.api.items.get_by_barcode to resolve item_name.
    ref.read(transferDraftProvider.notifier).addLine(
          TransferLine(itemCode: result.barcode, qty: 1),
        );
  }
}

class _WarehouseDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _WarehouseDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((w) => DropdownMenuItem(value: w, child: Text(w)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _LineTile extends StatelessWidget {
  final TransferLine line;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;
  const _LineTile({
    required this.line,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(line.itemCode),
      subtitle: line.itemName != null ? Text(line.itemName!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: line.qty.toString(),
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null) onQtyChanged(q);
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
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
