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
import '../../transfer/presentation/widgets/warehouse_location_dropdown.dart';
import '../domain/receipt_draft.dart';
import 'providers/receipt_providers.dart';

class ReceiptScreen extends ConsumerWidget {
  final Item? initialItem;

  const ReceiptScreen({super.key, this.initialItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(receiptDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final poAsync = ref.watch(purchaseOrdersProvider);
    final canSubmit = draft.isSubmittable && warehousesAsync.hasValue;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.receiveStock)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is CompanySelectionRequiredException
            ? const _CompanyRequiredView()
            : _ErrorView(
                message: context.l10n.failedToLoadWarehouses(e.toString()),
              ),
        data: (warehouses) => _ReceiptBody(
          draft: draft,
          warehouses: warehouses,
          poAsync: poAsync,
          initialItem: initialItem,
        ),
      ),
      bottomNavigationBar: draft.lines.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(context.l10n.queueReceipt),
                onPressed:
                    canSubmit ? () => _submit(context, ref, draft) : null,
              ),
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReceiptDraft draft,
  ) async {
    final company = ref.read(operationCompanyProvider).valueOrNull ??
        ref.read(settingsNotifierProvider).activeCompany;
    final id = await ref
        .read(submitReceiptUseCaseProvider)
        .call(draft.copyWith(company: company));
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
  final Item? initialItem;

  const _ReceiptBody({
    required this.draft,
    required this.warehouses,
    required this.poAsync,
    required this.initialItem,
  });

  @override
  ConsumerState<_ReceiptBody> createState() => _ReceiptBodyState();
}

class _ReceiptBodyState extends ConsumerState<_ReceiptBody> {
  bool _seedAttempted = false;
  bool _defaultsAttempted = false;
  bool _initialItemAlreadyInDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedInitialItem());
  }

  @override
  void didUpdateWidget(covariant _ReceiptBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItem?.itemCode != widget.initialItem?.itemCode) {
      _seedAttempted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _seedInitialItem());
    }
  }

  void _seedInitialItem() {
    final item = widget.initialItem;
    if (!mounted || item == null || _seedAttempted) return;

    final draft = ref.read(receiptDraftProvider);
    final exists = draft.lines.any((line) => line.itemCode == item.itemCode);
    _seedAttempted = true;
    _initialItemAlreadyInDraft = exists;

    if (!exists) {
      ref.read(receiptDraftProvider.notifier).addLineIfAbsent(
            ReceiptLine(
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
    final draft = ref.read(receiptDraftProvider);
    final defaultTarget = settings.defaultTargetWarehouse;
    if (draft.targetWarehouse != null ||
        defaultTarget == null ||
        !widget.warehouses.contains(defaultTarget)) {
      return;
    }
    _defaultsAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(receiptDraftProvider).targetWarehouse != null) {
        return;
      }
      ref.read(receiptDraftProvider.notifier).setTarget(defaultTarget);
    });
  }

  void _clearInvalidWarehouse() {
    final target = ref.read(receiptDraftProvider).targetWarehouse;
    if (target == null || widget.warehouses.contains(target)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(receiptDraftProvider).targetWarehouse;
      if (latest != null && !widget.warehouses.contains(latest)) {
        ref.read(receiptDraftProvider.notifier).setTarget(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsNotifierProvider);
    _clearInvalidWarehouse();
    _applyWarehouseDefaults();
    final notifier = ref.read(receiptDraftProvider.notifier);
    final totalQty =
        widget.draft.lines.fold<double>(0, (sum, line) => sum + line.qty);
    final seededItemCode = widget.initialItem?.itemCode;
    final seededItemInDraft = seededItemCode != null &&
        widget.draft.lines.any((line) => line.itemCode == seededItemCode);

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
            BudeStatusChip(
              label: context.l10n.poOptional,
              icon: Icons.assignment_outlined,
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
        _Dropdown(
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
              onTrackingPressed: () => _editTracking(context, line),
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
          hasBatchNo: scanned.item.hasBatchNo,
          hasSerialNo: scanned.item.hasSerialNo,
        ),
      );
    }
  }

  Future<void> _editTracking(BuildContext context, ReceiptLine line) async {
    final updated = await showTrackingAllocationPicker(
      context,
      ref,
      TrackingLineInfo(
        itemCode: line.itemCode,
        qty: line.qty,
        hasBatchNo: line.hasBatchNo,
        hasSerialNo: line.hasSerialNo,
        receiptMode: true,
        warehouse: widget.draft.targetLocation ?? widget.draft.targetWarehouse,
        allocations: line.allocations,
      ),
    );
    if (updated == null || !mounted) return;
    ref
        .read(receiptDraftProvider.notifier)
        .updateAllocations(line.itemCode, updated);
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
    final effectiveValue =
        value == null || options.contains(value) ? value : null;
    final items = [
      if (allowClear)
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.l10n.noneSelected),
        ),
      ...options.map((w) => DropdownMenuItem(value: w, child: Text(w))),
    ];
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
  final ReceiptLine line;
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
