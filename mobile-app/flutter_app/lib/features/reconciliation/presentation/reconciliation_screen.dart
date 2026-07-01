import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../inventory/domain/entities/item.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../../tracking/presentation/tracking_allocation_picker.dart';
import '../../transfer/presentation/widgets/warehouse_location_dropdown.dart';
import '../domain/reconciliation_draft.dart';
import 'providers/reconciliation_providers.dart';

class ReconciliationScreen extends ConsumerWidget {
  final Item? initialItem;

  const ReconciliationScreen({super.key, this.initialItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(reconciliationDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final canSubmit = draft.isSubmittable && warehousesAsync.hasValue;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.stockCount)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is CompanySelectionRequiredException
            ? const _CompanyRequiredView()
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      Text(context.l10n.failedToLoadWarehouses(e.toString())),
                ),
              ),
        data: (warehouses) => _Body(
          draft: draft,
          warehouses: warehouses,
          initialItem: initialItem,
        ),
      ),
      bottomNavigationBar: draft.lines.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(context.l10n.queueCount),
                onPressed:
                    canSubmit ? () => _submit(context, ref, draft) : null,
              ),
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReconciliationDraft draft,
  ) async {
    final settings = ref.read(settingsNotifierProvider);
    final company = ref.read(operationCompanyProvider).valueOrNull ??
        settings.activeCompany;
    final draftWithCompany = draft.copyWith(company: company);

    final threshold = settings.reconciliationVarianceThreshold;
    final totalVariance = draftWithCompany.totalVariance;
    final needsApproval =
        threshold > 0 && totalVariance > threshold;
    final totalVarianceText = formatOperationalQty(totalVariance);
    final thresholdText = formatOperationalQty(threshold);

    final initialStatus =
        needsApproval ? OpStatus.pendingApproval : OpStatus.pending;
    final id = await ref
        .read(submitReconciliationUseCaseProvider)
        .callWithStatus(
          draftWithCompany,
          initialStatus,
          extraPayload: needsApproval
              ? {
                  'approval_reason':
                      'Count variance $totalVarianceText exceeds threshold '
                          '$thresholdText.',
                  'approval_metric': 'count_variance',
                  'approval_threshold': threshold,
                }
              : const {},
        );

    ref.read(reconciliationDraftProvider.notifier).clear();

    if (!context.mounted) return;

    if (needsApproval) {
      context.push('/reconcile/approve', extra: id);
      return;
    }

    // ignore: discarded_futures
    ref.read(syncEngineProvider).kick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.countQueued(id)),
        action: SnackBarAction(
          label: context.l10n.openSync,
          onPressed: () => context.push('/sync'),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final ReconciliationDraft draft;
  final List<String> warehouses;
  final Item? initialItem;

  const _Body({
    required this.draft,
    required this.warehouses,
    required this.initialItem,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _defaultsAttempted = false;
  bool _seedAttempted = false;
  bool _initialItemAlreadyInDraft = false;

  @override
  void didUpdateWidget(covariant _Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItem?.itemCode != widget.initialItem?.itemCode) {
      _seedAttempted = false;
      _initialItemAlreadyInDraft = false;
    }
  }

  void _maybeSeedInitialItem() {
    final item = widget.initialItem;
    if (item == null || widget.draft.warehouse == null || _seedAttempted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seedAttempted) return;
      final draft = ref.read(reconciliationDraftProvider);
      if (draft.warehouse == null) return;

      final exists = draft.lines.any((line) => line.itemCode == item.itemCode);
      _seedAttempted = true;
      _initialItemAlreadyInDraft = exists;

      if (!exists) {
        ref.read(reconciliationDraftProvider.notifier).addLineIfAbsent(
              CountLine(
                itemCode: item.itemCode,
                itemName: item.itemName,
                countedQty: 1,
                hasBatchNo: item.hasBatchNo,
                hasSerialNo: item.hasSerialNo,
              ),
            );
      } else {
        setState(() {});
      }
    });
  }

  void _maybeApplyWarehouseDefault() {
    if (!mounted || _defaultsAttempted) return;

    final draft = ref.read(reconciliationDraftProvider);
    final defaultWarehouse =
        ref.read(settingsNotifierProvider).defaultSourceWarehouse;
    if (draft.warehouse != null ||
        defaultWarehouse == null ||
        !widget.warehouses.contains(defaultWarehouse)) {
      return;
    }
    _defaultsAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(reconciliationDraftProvider.notifier).setWarehouse(
            defaultWarehouse,
          );
    });
  }

  void _clearInvalidWarehouse() {
    final warehouse = ref.read(reconciliationDraftProvider).warehouse;
    if (warehouse == null || widget.warehouses.contains(warehouse)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(reconciliationDraftProvider).warehouse;
      if (latest != null && !widget.warehouses.contains(latest)) {
        ref.read(reconciliationDraftProvider.notifier).setWarehouse(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsNotifierProvider);
    _clearInvalidWarehouse();
    _maybeApplyWarehouseDefault();
    _maybeSeedInitialItem();
    final notifier = ref.read(reconciliationDraftProvider.notifier);
    final totalCounted = widget.draft.lines.fold<double>(
      0,
      (sum, line) => sum + line.countedQty,
    );
    final seededItemCode = widget.initialItem?.itemCode;
    final seededItemInDraft = seededItemCode != null &&
        widget.draft.lines.any((line) => line.itemCode == seededItemCode);
    final selectedWarehouse = widget.warehouses.contains(widget.draft.warehouse)
        ? widget.draft.warehouse
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.fact_check,
          title: context.l10n.stockCount,
          subtitle: context.l10n.stockCountSubtitle,
          pills: [
            BudeSummaryPill(
              icon: Icons.inventory_2_outlined,
              label: context.l10n.lines,
              value: '${widget.draft.lines.length}',
            ),
            BudeSummaryPill(
              icon: Icons.functions,
              label: context.l10n.counted,
              value: formatOperationalQty(totalCounted),
            ),
            BudeStatusChip(
              label: widget.draft.isSubmittable
                  ? context.l10n.ready
                  : context.l10n.needsWarehouse,
              icon: widget.draft.isSubmittable
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: widget.draft.isSubmittable
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.tertiary,
            ),
            if (widget.draft.warehouse == null)
              BudeStatusChip(
                label: context.l10n.needsWarehouse,
                icon: Icons.warehouse_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            if (widget.draft.lines.isEmpty)
              BudeStatusChip(
                label: context.l10n.needsItems,
                icon: Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            if (widget.initialItem != null && widget.draft.warehouse == null)
              BudeStatusChip(
                label: context.l10n.pickWarehouseToCountItem(
                  widget.initialItem!.itemCode,
                ),
                icon: Icons.add_location_alt_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            if (seededItemInDraft)
              BudeStatusChip(
                label: _initialItemAlreadyInDraft
                    ? context.l10n.alreadyInDraft(widget.initialItem!.itemCode)
                    : context.l10n.itemAddedToDraft(
                        widget.initialItem!.itemCode,
                      ),
                icon: Icons.add_task,
                color: Theme.of(context).colorScheme.secondary,
              ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('warehouse-$selectedWarehouse'),
          initialValue: selectedWarehouse,
          decoration: InputDecoration(
            labelText: context.l10n.warehouse,
            border: const OutlineInputBorder(),
            helperText: context.l10n.changingWarehouseClearsCount,
          ),
          items: widget.warehouses
              .map((w) => DropdownMenuItem(value: w, child: Text(w)))
              .toList(),
          onChanged: notifier.setWarehouse,
        ),
        if (widget.draft.warehouse != null) ...[
          const SizedBox(height: 12),
          WarehouseLocationDropdown(
            label: context.l10n.countLocation,
            warehouse: widget.draft.warehouse!,
            value: widget.draft.location,
            helperText: context.l10n.changingWarehouseClearsCount,
            onChanged: notifier.setLocation,
          ),
        ],
        const Divider(height: 32),
        Row(
          children: [
            Text(
              context.l10n.countedItems(widget.draft.lines.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.startScanSession),
              onPressed: widget.draft.warehouse == null
                  ? null
                  : () => _startScanSession(
                        context,
                        widget.draft.location ?? widget.draft.warehouse!,
                      ),
            ),
          ],
        ),
        if (widget.draft.warehouse == null)
          EmptyStateView(
            icon: Icons.warehouse_outlined,
            title: context.l10n.pickWarehouseFirst,
            subtitle: context.l10n.pickWarehouseFirstSubtitle,
          )
        else if (widget.draft.lines.isEmpty)
          EmptyStateView(
            icon: Icons.qr_code_scanner,
            title: context.l10n.scanItemsToCount,
            subtitle: context.l10n.startScanCountSubtitle,
            action: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.startScanSession),
              onPressed: () => _startScanSession(
                context,
                widget.draft.location ?? widget.draft.warehouse!,
              ),
            ),
          )
        else
          ...widget.draft.lines.map(
            (line) => _CountTile(
              line: line,
              onCountChanged: (q) => notifier.setCount(line.itemCode, q),
              onTrackingPressed: () => _editTracking(context, line),
              onRemove: () => notifier.removeLine(line.itemCode),
            ),
          ),
      ],
    );
  }

  Future<void> _startScanSession(
    BuildContext context,
    String warehouse,
  ) async {
    final result =
        await context.push<List<ScannedItem>>('/scan-session?mode=reconcile');
    if (result == null || result.isEmpty || !context.mounted) return;

    final expectedFutures = result
        .map(
          (s) => ref.read(
            expectedQtyProvider(BinKey(s.item.itemCode, warehouse)).future,
          ),
        )
        .toList();
    final expectedQtys = await Future.wait(expectedFutures);
    if (!mounted) return;

    final notifier = ref.read(reconciliationDraftProvider.notifier);
    for (var i = 0; i < result.length; i++) {
      final scanned = result[i];
      notifier.addLine(
        CountLine(
          itemCode: scanned.item.itemCode,
          itemName: scanned.item.itemName,
          countedQty: scanned.qty,
          expectedQty: expectedQtys[i],
          hasBatchNo: scanned.item.hasBatchNo,
          hasSerialNo: scanned.item.hasSerialNo,
        ),
      );
    }
  }

  Future<void> _editTracking(BuildContext context, CountLine line) async {
    final updated = await showTrackingAllocationPicker(
      context,
      ref,
      TrackingLineInfo(
        itemCode: line.itemCode,
        qty: line.countedQty,
        hasBatchNo: line.hasBatchNo,
        hasSerialNo: line.hasSerialNo,
        warehouse: widget.draft.location ?? widget.draft.warehouse,
        allocations: line.allocations,
      ),
    );
    if (updated == null || !mounted) return;
    ref
        .read(reconciliationDraftProvider.notifier)
        .updateAllocations(line.itemCode, updated);
  }
}

class _CountTile extends StatelessWidget {
  final CountLine line;
  final ValueChanged<double> onCountChanged;
  final VoidCallback onTrackingPressed;
  final VoidCallback onRemove;

  const _CountTile({
    required this.line,
    required this.onCountChanged,
    required this.onTrackingPressed,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final variance = line.variance;

    Color varianceColor() {
      if (variance == null || variance == 0) return scheme.primary;
      return variance > 0 ? scheme.tertiary : scheme.error;
    }

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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (line.expectedQty != null)
                          BudeStatusChip(
                            label: context.l10n.expectedQtyShort(
                              formatOperationalQty(line.expectedQty!),
                            ),
                            icon: Icons.fact_check_outlined,
                            color: scheme.primary,
                          ),
                        if (variance != null)
                          BudeStatusChip(
                            label: context.l10n.varianceQtyShort(
                              formatOperationalQty(variance),
                            ),
                            icon: variance == 0
                                ? Icons.check_circle_outline
                                : Icons.change_circle_outlined,
                            color: varianceColor(),
                          ),
                      ],
                    ),
                    TrackingChips(allocations: line.allocations),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BudeQuantityControl(
                value: line.countedQty,
                onChanged: onCountChanged,
              ),
              IconButton(
                tooltip: context.l10n.removeItem,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
              ),
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

class _CompanyRequiredView extends StatelessWidget {
  const _CompanyRequiredView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.business_outlined,
      title: context.l10n.selectCompany,
      subtitle: context.l10n.selectCompanyBeforeWarehouses,
    );
  }
}
