import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/error_banner.dart';
import '../domain/receipt_draft.dart';
import 'providers/receipt_providers.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(receiptDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final poAsync = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receive stock')),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: 'Failed to load warehouses: $e'),
        data: (warehouses) => _ReceiptBody(
          draft: draft,
          warehouses: warehouses,
          poAsync: poAsync,
        ),
      ),
      floatingActionButton: draft.lines.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: const Text('Queue receipt'),
              onPressed: draft.isSubmittable ? () => _submit(context, ref, draft) : null,
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReceiptDraft draft,
  ) async {
    final id = await ref.read(submitReceiptUseCaseProvider).call(draft);
    // ignore: discarded_futures
    ref.read(syncEngineProvider).kick();
    ref.read(receiptDraftProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt queued (op $id). Watch /sync for status.'),
        action: SnackBarAction(
          label: 'Open sync',
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
  }
}

class _ReceiptBody extends ConsumerWidget {
  final ReceiptDraft draft;
  final List<String> warehouses;
  final AsyncValue<List<String>> poAsync;

  const _ReceiptBody({
    required this.draft,
    required this.warehouses,
    required this.poAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(receiptDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Dropdown(
          label: 'Target warehouse',
          value: draft.targetWarehouse,
          options: warehouses,
          onChanged: notifier.setTarget,
        ),
        const SizedBox(height: 12),
        poAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErrorText('Could not load POs: $e'),
          data: (pos) => _Dropdown(
            label: 'Against PO (optional)',
            value: draft.againstPo,
            options: pos,
            allowClear: true,
            onChanged: notifier.setAgainstPo,
          ),
        ),
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
    ref.read(receiptDraftProvider.notifier).addLine(
          ReceiptLine(itemCode: result.barcode, qty: 1),
        );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final bool allowClear;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowClear = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      if (allowClear)
        const DropdownMenuItem<String>(value: null, child: Text('— none —')),
      ...options.map((w) => DropdownMenuItem(value: w, child: Text(w))),
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _LineTile extends StatelessWidget {
  final ReceiptLine line;
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
