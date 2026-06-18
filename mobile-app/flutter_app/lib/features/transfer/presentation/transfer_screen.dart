import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/utils/locale_ext.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../domain/transfer_draft.dart';
import 'providers/transfer_providers.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(transferDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.stockTransfer)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorView(message: context.l10n.failedToLoadWarehouses(e.toString())),
        data: (warehouses) => _TransferBody(
          draft: draft,
          warehouses: warehouses,
        ),
      ),
      floatingActionButton: draft.lines.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: Text(context.l10n.queueTransfer),
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
    final settings = ref.read(settingsNotifierProvider);
    final id = await ref
        .read(submitTransferUseCaseProvider)
        .call(draft.copyWith(company: settings.activeCompany));
    unawaited(ref.read(syncEngineProvider).kick());
    ref.read(transferDraftProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.transferQueued(id)),
        action: SnackBarAction(
          label: context.l10n.openSync,
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

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(transferDraftProvider.notifier);
    final sameWarehouseError = widget.draft.sourceWarehouse != null &&
        widget.draft.sourceWarehouse == widget.draft.targetWarehouse;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WarehouseDropdown(
          label: context.l10n.sourceWarehouse,
          value: widget.draft.sourceWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setSource,
        ),
        const SizedBox(height: 12),
        _WarehouseDropdown(
          label: context.l10n.targetWarehouse,
          value: widget.draft.targetWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setTarget,
        ),
        if (sameWarehouseError) ...[
          const SizedBox(height: 8),
          ErrorText(context.l10n.sourceTargetMustDiffer),
        ],
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
        await context.push<List<ScannedItem>>('/scan-session?mode=transfer');
    if (result == null || result.isEmpty || !context.mounted) return;
    final notifier = ref.read(transferDraftProvider.notifier);
    for (final scanned in result) {
      notifier.addLine(TransferLine(
        itemCode: scanned.item.itemCode,
        itemName: scanned.item.itemName,
        qty: scanned.qty,
      ),);
    }
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
