import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../tracking/presentation/tracking_allocation_picker.dart';
import '../../transfer/presentation/providers/transfer_providers.dart';
import '../../transfer/presentation/widgets/warehouse_location_dropdown.dart';
import '../domain/fulfillment_draft.dart';
import 'providers/fulfillment_providers.dart';

class SalesOrderFulfillmentScreen extends ConsumerWidget {
  final String salesOrder;
  final String? todoName;

  const SalesOrderFulfillmentScreen({
    super.key,
    required this.salesOrder,
    this.todoName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(salesOrderDetailProvider(salesOrder));
    final draft = ref.watch(fulfillmentDraftProvider(salesOrder));
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(salesOrder)),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (order) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(fulfillmentDraftProvider(salesOrder).notifier)
                .ensureSeeded(order, todoName: todoName);
          });
          final effectiveDraft =
              draft ?? FulfillmentDraft.fromSalesOrder(order);
          return warehousesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(e.toString(), textAlign: TextAlign.center),
              ),
            ),
            data: (warehouses) => _FulfillmentBody(
              draft: effectiveDraft,
              warehouses: warehouses,
            ),
          );
        },
      ),
    );
  }
}

class _FulfillmentBody extends ConsumerWidget {
  final FulfillmentDraft draft;
  final List<String> warehouses;
  const _FulfillmentBody({required this.draft, required this.warehouses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      fulfillmentDraftProvider(draft.salesOrder).notifier,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.local_shipping_outlined,
          title: context.l10n.fulfillment,
          subtitle: draft.customer ?? draft.salesOrder,
          pills: [
            BudeSummaryPill(
              icon: Icons.inventory_2_outlined,
              label: context.l10n.lines,
              value: '${draft.lines.length}',
            ),
            BudeSummaryPill(
              icon: Icons.functions,
              label: context.l10n.totalQty,
              value: formatOperationalQty(draft.totalRequired),
            ),
            BudeStatusChip(
              label: _stageLabel(context, draft.stage),
              icon: Icons.route_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<FulfillmentStage>(
          segments: [
            ButtonSegment(
              value: FulfillmentStage.pick,
              icon: const Icon(Icons.playlist_add_check),
              label: Text(context.l10n.pick),
            ),
            ButtonSegment(
              value: FulfillmentStage.pack,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(context.l10n.pack),
            ),
            ButtonSegment(
              value: FulfillmentStage.dispatch,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(context.l10n.dispatch),
            ),
          ],
          selected: {draft.stage},
          onSelectionChanged: (selection) =>
              notifier.setStage(selection.single),
        ),
        const SizedBox(height: 16),
        switch (draft.stage) {
          FulfillmentStage.pick => _PickStage(
              draft: draft,
              warehouses: warehouses,
            ),
          FulfillmentStage.pack => _PackStage(draft: draft),
          FulfillmentStage.dispatch => _DispatchStage(draft: draft),
        },
      ],
    );
  }
}

class _PickStage extends ConsumerWidget {
  final FulfillmentDraft draft;
  final List<String> warehouses;
  const _PickStage({required this.draft, required this.warehouses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      fulfillmentDraftProvider(draft.salesOrder).notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Dropdown(
          label: context.l10n.sourceWarehouse,
          value: draft.sourceWarehouse,
          options: warehouses,
          onChanged: notifier.setSource,
        ),
        if (draft.sourceWarehouse != null) ...[
          const SizedBox(height: 12),
          WarehouseLocationDropdown(
            label: context.l10n.sourceLocation,
            warehouse: draft.sourceWarehouse!,
            value: draft.sourceLocation,
            onChanged: notifier.setSourceLocation,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(context.l10n.startScanSession),
          onPressed: () => _startScan(context, ref, draft),
        ),
        const SizedBox(height: 12),
        ...draft.lines.map(
          (line) => _FulfillmentLineTile(
            line: line,
            value: line.pickedQty,
            status: line.pickedExact
                ? context.l10n.exact
                : context.l10n.requiredQty(
                    formatOperationalQty(line.requiredQty),
                  ),
            onChanged: (qty) => notifier.setPickedQty(line.salesOrderItem, qty),
            onTrackingPressed: () => _editTracking(context, ref, draft, line),
          ),
        ),
        if (!draft.isPickedExact) ErrorText(context.l10n.exactPickRequired),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(context.l10n.continueToPack),
          onPressed: draft.isPickedExact
              ? () => notifier.setStage(FulfillmentStage.pack)
              : null,
        ),
      ],
    );
  }

  Future<void> _startScan(
    BuildContext context,
    WidgetRef ref,
    FulfillmentDraft draft,
  ) async {
    final result =
        await context.push<List<ScannedItem>>('/scan-session?mode=transfer');
    if (result == null || result.isEmpty) return;
    final notifier = ref.read(
      fulfillmentDraftProvider(draft.salesOrder).notifier,
    );
    for (final scanned in result) {
      await notifier.addPickedItem(scanned.item.itemCode, scanned.qty);
    }
  }

  Future<void> _editTracking(
    BuildContext context,
    WidgetRef ref,
    FulfillmentDraft draft,
    FulfillmentLine line,
  ) async {
    final updated = await showTrackingAllocationPicker(
      context,
      ref,
      TrackingLineInfo(
        itemCode: line.itemCode,
        qty: line.requiredQty,
        hasBatchNo: line.hasBatchNo,
        hasSerialNo: line.hasSerialNo,
        warehouse: draft.sourceLocation ?? draft.sourceWarehouse,
        allocations: line.allocations,
      ),
    );
    if (updated == null) return;
    await ref
        .read(fulfillmentDraftProvider(draft.salesOrder).notifier)
        .setAllocations(line.salesOrderItem, updated);
  }
}

class _PackStage extends ConsumerWidget {
  final FulfillmentDraft draft;
  const _PackStage({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      fulfillmentDraftProvider(draft.salesOrder).notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!draft.isPickedExact) ErrorText(context.l10n.exactPickRequired),
        ...draft.lines.map(
          (line) => _FulfillmentLineTile(
            line: line,
            value: line.packedQty,
            status: line.packedExact
                ? context.l10n.exact
                : context.l10n.requiredQty(
                    formatOperationalQty(line.requiredQty),
                  ),
            onChanged: (qty) => notifier.setPackedQty(line.salesOrderItem, qty),
            onTrackingPressed: null,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.done_all),
          label: Text(context.l10n.confirmPacked),
          onPressed:
              draft.isPickedExact ? notifier.confirmPickedAsPacked : null,
        ),
      ],
    );
  }
}

class _DispatchStage extends ConsumerWidget {
  final FulfillmentDraft draft;
  const _DispatchStage({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!draft.canDispatch)
          ErrorText(
            draft.sourceWarehouse == null
                ? context.l10n.pickWarehouseFirst
                : context.l10n.exactPackRequired,
          ),
        EmptyStateView(
          icon: Icons.local_shipping_outlined,
          title: context.l10n.readyToDispatch,
          subtitle: context.l10n.readyToDispatchSubtitle(draft.salesOrder),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.send),
          label: Text(context.l10n.queueDispatch),
          onPressed:
              draft.canDispatch ? () => _submit(context, ref, draft) : null,
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    FulfillmentDraft draft,
  ) async {
    final id =
        await ref.read(submitSalesOrderDispatchUseCaseProvider).call(draft);
    await ref.read(fulfillmentDraftProvider(draft.salesOrder).notifier).clear();
    // ignore: discarded_futures
    ref.read(syncEngineProvider).kick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.dispatchQueued(id)),
        action: SnackBarAction(
          label: context.l10n.openSync,
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
    context.pop();
  }
}

class _FulfillmentLineTile extends StatelessWidget {
  final FulfillmentLine line;
  final double value;
  final String status;
  final ValueChanged<double> onChanged;
  final VoidCallback? onTrackingPressed;
  const _FulfillmentLineTile({
    required this.line,
    required this.value,
    required this.status,
    required this.onChanged,
    this.onTrackingPressed,
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
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.itemCode),
                    if (line.itemName != null)
                      Text(
                        line.itemName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(status, style: Theme.of(context).textTheme.bodySmall),
                    TrackingChips(allocations: line.allocations),
                  ],
                ),
              ),
              BudeQuantityControl(value: value, onChanged: onChanged),
              if (line.hasBatchNo || line.hasSerialNo)
                IconButton(
                  tooltip: context.l10n.tracking,
                  icon: Icon(
                    line.isTrackingComplete
                        ? Icons.check_circle_outline
                        : Icons.inventory_outlined,
                  ),
                  onPressed: onTrackingPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValue =
        value == null || options.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$effectiveValue'),
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

String _stageLabel(BuildContext context, FulfillmentStage stage) {
  return switch (stage) {
    FulfillmentStage.pick => context.l10n.pick,
    FulfillmentStage.pack => context.l10n.pack,
    FulfillmentStage.dispatch => context.l10n.dispatch,
  };
}
