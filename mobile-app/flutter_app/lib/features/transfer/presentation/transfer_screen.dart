import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../inventory/domain/entities/item.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../../tracking/presentation/tracking_allocation_picker.dart';
import '../domain/transfer_draft.dart';
import 'providers/transfer_providers.dart';
import 'widgets/warehouse_location_dropdown.dart';

class TransferScreen extends ConsumerWidget {
  final Item? initialItem;

  const TransferScreen({super.key, this.initialItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(transferDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final canSubmit = draft.isSubmittable && warehousesAsync.hasValue;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.stockTransfer)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is CompanySelectionRequiredException
            ? const _CompanyRequiredView()
            : _ErrorView(
                message: context.l10n.failedToLoadWarehouses(e.toString()),
              ),
        data: (warehouses) => _TransferBody(
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
                label: Text(context.l10n.queueTransfer),
                onPressed:
                    canSubmit ? () => _submit(context, ref, draft) : null,
              ),
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    TransferDraft draft,
  ) async {
    final company = ref.read(operationCompanyProvider).valueOrNull ??
        ref.read(settingsNotifierProvider).activeCompany;
    final id = await ref
        .read(submitTransferUseCaseProvider)
        .call(draft.copyWith(company: company));
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
  final Item? initialItem;
  const _TransferBody({
    required this.draft,
    required this.warehouses,
    required this.initialItem,
  });

  @override
  ConsumerState<_TransferBody> createState() => _TransferBodyState();
}

class _TransferBodyState extends ConsumerState<_TransferBody> {
  bool _seedAttempted = false;
  bool _defaultsAttempted = false;
  bool _initialItemAlreadyInDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedInitialItem());
  }

  @override
  void didUpdateWidget(covariant _TransferBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItem?.itemCode != widget.initialItem?.itemCode) {
      _seedAttempted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _seedInitialItem());
    }
  }

  void _seedInitialItem() {
    final item = widget.initialItem;
    if (!mounted || item == null || _seedAttempted) return;

    final draft = ref.read(transferDraftProvider);
    final exists = draft.lines.any((line) => line.itemCode == item.itemCode);
    _seedAttempted = true;
    _initialItemAlreadyInDraft = exists;

    if (!exists) {
      ref.read(transferDraftProvider.notifier).addLineIfAbsent(
            TransferLine(
              itemCode: item.itemCode,
              itemName: item.itemName,
              qty: 1,
              hasBatchNo: item.hasBatchNo,
              hasSerialNo: item.hasSerialNo,
            ),
          );
    } else {
      setState(() {});
    }
  }

  void _applyWarehouseDefaults() {
    if (!mounted || _defaultsAttempted) return;

    final settings = ref.read(settingsNotifierProvider);
    final notifier = ref.read(transferDraftProvider.notifier);
    final warehouses = widget.warehouses.toSet();
    final defaultSource = settings.defaultSourceWarehouse;
    final defaultTarget = settings.defaultTargetWarehouse;
    if (defaultSource == null && defaultTarget == null) return;

    _defaultsAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(transferDraftProvider);
      if (latest.sourceWarehouse == null &&
          defaultSource != null &&
          warehouses.contains(defaultSource)) {
        notifier.setSource(defaultSource);
      }

      final effectiveSource = latest.sourceWarehouse ?? defaultSource;
      if (latest.targetWarehouse == null &&
          defaultTarget != null &&
          warehouses.contains(defaultTarget) &&
          defaultTarget != effectiveSource) {
        notifier.setTarget(defaultTarget);
      }
    });
  }

  void _clearInvalidWarehouses() {
    final allowed = widget.warehouses.toSet();
    final draft = ref.read(transferDraftProvider);
    final invalidSource = draft.sourceWarehouse != null &&
        !allowed.contains(draft.sourceWarehouse);
    final invalidTarget = draft.targetWarehouse != null &&
        !allowed.contains(draft.targetWarehouse);
    if (!invalidSource && !invalidTarget) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(transferDraftProvider);
      final notifier = ref.read(transferDraftProvider.notifier);
      if (latest.sourceWarehouse != null &&
          !allowed.contains(latest.sourceWarehouse)) {
        notifier.setSource(null);
      }
      if (latest.targetWarehouse != null &&
          !allowed.contains(latest.targetWarehouse)) {
        notifier.setTarget(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsNotifierProvider);
    _clearInvalidWarehouses();
    _applyWarehouseDefaults();
    final notifier = ref.read(transferDraftProvider.notifier);
    final sameWarehouseError = widget.draft.sourceWarehouse != null &&
        widget.draft.sourceWarehouse == widget.draft.targetWarehouse;
    final totalQty =
        widget.draft.lines.fold<double>(0, (sum, line) => sum + line.qty);
    final seededItemCode = widget.initialItem?.itemCode;
    final seededItemInDraft = seededItemCode != null &&
        widget.draft.lines.any((line) => line.itemCode == seededItemCode);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.swap_horiz,
          title: context.l10n.stockTransfer,
          subtitle: context.l10n.stockTransferSubtitle,
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
            if (widget.draft.sourceWarehouse == null)
              BudeStatusChip(
                label: context.l10n.needsSource,
                icon: Icons.outbox_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            if (widget.draft.targetWarehouse == null)
              BudeStatusChip(
                label: context.l10n.needsTarget,
                icon: Icons.move_to_inbox_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            if (widget.draft.lines.isEmpty)
              BudeStatusChip(
                label: context.l10n.needsItems,
                icon: Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.tertiary,
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
        _WarehouseDropdown(
          label: context.l10n.sourceWarehouse,
          value: widget.draft.sourceWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setSource,
        ),
        if (widget.draft.sourceWarehouse != null) ...[
          const SizedBox(height: 12),
          WarehouseLocationDropdown(
            label: context.l10n.sourceLocation,
            warehouse: widget.draft.sourceWarehouse!,
            value: widget.draft.sourceLocation,
            onChanged: notifier.setSourceLocation,
          ),
        ],
        const SizedBox(height: 12),
        _WarehouseDropdown(
          label: context.l10n.targetWarehouse,
          value: widget.draft.targetWarehouse,
          options: widget.warehouses,
          onChanged: notifier.setTarget,
        ),
        if (widget.draft.targetWarehouse != null) ...[
          const SizedBox(height: 12),
          WarehouseLocationDropdown(
            label: context.l10n.targetLocation,
            warehouse: widget.draft.targetWarehouse!,
            value: widget.draft.targetLocation,
            onChanged: notifier.setTargetLocation,
          ),
        ],
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
          EmptyStateView(
            icon: Icons.qr_code_scanner,
            title: context.l10n.noItemsYet,
            subtitle: context.l10n.startScanTransferLines,
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
              onTrackingPressed: () => _editTracking(context, line),
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
      notifier.addLine(
        TransferLine(
          itemCode: scanned.item.itemCode,
          itemName: scanned.item.itemName,
          qty: scanned.qty,
          hasBatchNo: scanned.item.hasBatchNo,
          hasSerialNo: scanned.item.hasSerialNo,
        ),
      );
    }
  }

  Future<void> _editTracking(BuildContext context, TransferLine line) async {
    final updated = await showTrackingAllocationPicker(
      context,
      ref,
      TrackingLineInfo(
        itemCode: line.itemCode,
        qty: line.qty,
        hasBatchNo: line.hasBatchNo,
        hasSerialNo: line.hasSerialNo,
        warehouse: widget.draft.sourceLocation ?? widget.draft.sourceWarehouse,
        allocations: line.allocations,
      ),
    );
    if (updated == null || !mounted) return;
    ref
        .read(transferDraftProvider.notifier)
        .updateAllocations(line.itemCode, updated);
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
    final effectiveValue =
        value == null || options.contains(value) ? value : null;
    final items =
        options.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$effectiveValue'),
      initialValue: effectiveValue,
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
  final TransferLine line;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onTrackingPressed;
  final VoidCallback onRemove;
  const _LineTile({
    required this.line,
    required this.onQtyChanged,
    required this.onTrackingPressed,
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
                    TrackingChips(allocations: line.allocations),
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
