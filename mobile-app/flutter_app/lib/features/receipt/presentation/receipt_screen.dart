import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
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
        error: (e, _) => _ErrorView(
          message: context.l10n.failedToLoadWarehouses(e.toString()),
        ),
        data: (warehouses) => _ReceiptBody(
          draft: draft,
          warehouses: warehouses,
          poAsync: poAsync,
        ),
      ),
      bottomNavigationBar: draft.lines.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(context.l10n.queueReceipt),
                onPressed: draft.isSubmittable
                    ? () => _submit(context, ref, draft)
                    : null,
              ),
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReceiptDraft draft,
  ) async {
    final settings = ref.read(settingsNotifierProvider);
    final id = await ref
        .read(submitReceiptUseCaseProvider)
        .call(draft.copyWith(company: settings.activeCompany));
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
    final totalQty =
        widget.draft.lines.fold<double>(0, (sum, line) => sum + line.qty);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.input,
          title: context.l10n.receiveStock,
          subtitle: context.l10n.receiveStockSubtitle,
          pills: [
            BudeSummaryPill(
              icon: Icons.inventory_2_outlined,
              label: context.l10n.lines,
              value: '${widget.draft.lines.length}',
            ),
            BudeSummaryPill(
              icon: Icons.functions,
              label: context.l10n.totalQty,
              value: formatOperationalQty(totalQty),
            ),
            BudeStatusChip(
              label: widget.draft.againstPo == null
                  ? context.l10n.freeReceipt
                  : context.l10n.purchaseOrderShort,
              icon: widget.draft.againstPo == null
                  ? Icons.edit_note
                  : Icons.assignment_turned_in_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            BudeStatusChip(
              label: widget.draft.isSubmittable
                  ? context.l10n.ready
                  : context.l10n.needsDetails,
              icon: widget.draft.isSubmittable
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: widget.draft.isSubmittable
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          EmptyStateView(
            icon: Icons.qr_code_scanner,
            title: context.l10n.noItemsYet,
            subtitle: context.l10n.startScanReceiptLines,
            action: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.startScanSession),
              onPressed: () => _startScanSession(context),
            ),
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
      notifier.addLine(
        ReceiptLine(
          itemCode: scanned.item.itemCode,
          itemName: scanned.item.itemName,
          qty: scanned.qty,
        ),
      );
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.itemCode,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (line.itemName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        line.itemName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BudeQuantityControl(
                value: line.qty,
                min: 0.01,
                onChanged: onQtyChanged,
              ),
              IconButton(
                tooltip: context.l10n.removeItem,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
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
