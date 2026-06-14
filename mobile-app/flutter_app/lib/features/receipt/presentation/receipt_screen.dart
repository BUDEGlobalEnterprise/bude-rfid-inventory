import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/utils/locale_ext.dart';
import '../../scan_session/domain/scanned_item.dart';
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
      appBar: AppBar(title: Text(context.l10n.receiveStock)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorView(message: context.l10n.failedToLoadWarehouses(e.toString())),
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
              label: Text(context.l10n.queueReceipt),
              onPressed:
                  draft.isSubmittable ? () => _submit(context, ref, draft) : null,
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
        content: Text(context.l10n.receiptQueued(id)),
        action: SnackBarAction(
          label: context.l10n.openSync,
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
  }
}

class _ReceiptBody extends ConsumerStatefulWidget {
  final ReceiptDraft draft;
  final List<String> warehouses;
  final AsyncValue<List<String>> poAsync;

  const _ReceiptBody({
    required this.draft,
    required this.warehouses,
    required this.poAsync,
  });

  @override
  ConsumerState<_ReceiptBody> createState() => _ReceiptBodyState();
}

class _ReceiptBodyState extends ConsumerState<_ReceiptBody> {

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(receiptDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Dropdown(
          label: context.l10n.targetWarehouse,
          value: widget.draft.targetWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setTarget,
        ),
        const SizedBox(height: 12),
        widget.poAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              ErrorText(context.l10n.couldNotLoadPOs(e.toString())),
          data: (pos) => _Dropdown(
            label: context.l10n.againstPo,
            value: widget.draft.againstPo,
            options: pos,
            allowClear: true,
            onChanged: notifier.setAgainstPo,
          ),
        ),
        const Divider(height: 32),
        Row(
          children: [
            Text(
              context.l10n.items(widget.draft.lines.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.startScanSession),
              onPressed: () => _startScanSession(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.draft.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.noItemsYet),
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

  Future<void> _startScanSession(BuildContext context) async {
    final result =
        await context.push<List<ScannedItem>>('/scan-session?mode=receipt');
    if (result == null || result.isEmpty || !context.mounted) return;
    final notifier = ref.read(receiptDraftProvider.notifier);
    for (final scanned in result) {
      notifier.addLine(ReceiptLine(
        itemCode: scanned.item.itemCode,
        itemName: scanned.item.itemName,
        qty: scanned.qty,
      ),);
    }
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
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.l10n.noneSelected),
        ),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
