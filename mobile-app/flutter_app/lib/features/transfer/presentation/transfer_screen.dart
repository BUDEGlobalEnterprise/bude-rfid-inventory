import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/error_banner.dart';
import '../../inventory/presentation/providers/item_search_notifier.dart';
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

class _TransferBody extends ConsumerStatefulWidget {
  final TransferDraft draft;
  final List<String> warehouses;
  const _TransferBody({required this.draft, required this.warehouses});

  @override
  ConsumerState<_TransferBody> createState() => _TransferBodyState();
}

class _TransferBodyState extends ConsumerState<_TransferBody> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(transferDraftProvider.notifier);
    final sameWarehouseError = widget.draft.sourceWarehouse != null &&
        widget.draft.sourceWarehouse == widget.draft.targetWarehouse;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WarehouseDropdown(
          label: 'Source warehouse',
          value: widget.draft.sourceWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setSource,
        ),
        const SizedBox(height: 12),
        _WarehouseDropdown(
          label: 'Target warehouse',
          value: widget.draft.targetWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setTarget,
        ),
        if (sameWarehouseError) ...[
          const SizedBox(height: 8),
          const ErrorText('Source and target must differ.'),
        ],
        const Divider(height: 32),
        Row(
          children: [
            Text(
              'Items (${widget.draft.lines.length})',
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
              label: const Text('Scan to add'),
              onPressed: _resolving ? null : () => _scanAndAdd(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.draft.lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No items yet — scan or add manually.'),
          )
        else
          ...widget.draft.lines.map(
            (line) => _LineTile(
              line: line,
              onQtyChanged: (q) => notifier.updateQty(line.itemCode, q),
              onRemove: () => notifier.removeLine(line.itemCode),
            ),
          ),
      ],
    );
  }

  Future<void> _scanAndAdd(BuildContext context) async {
    final result = await context.push<ScanEvent>('/scan');
    if (result == null || !context.mounted) return;

    setState(() => _resolving = true);
    final useCase = ref.read(getItemByBarcodeUseCaseProvider);
    final either = await useCase(result.barcode);
    if (!mounted) return;
    setState(() => _resolving = false);

    either.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (item) {
        ref.read(transferDraftProvider.notifier).addLine(
              TransferLine(
                itemCode: item.itemCode,
                itemName: item.itemName,
                qty: 1,
              ),
            );
      },
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
