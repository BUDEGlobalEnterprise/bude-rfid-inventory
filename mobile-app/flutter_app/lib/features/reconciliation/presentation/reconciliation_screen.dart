import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/utils/locale_ext.dart';
import '../../scan_session/domain/scanned_item.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../domain/reconciliation_draft.dart';
import 'providers/reconciliation_providers.dart';

class ReconciliationScreen extends ConsumerWidget {
  const ReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(reconciliationDraftProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.stockCount)),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.failedToLoadWarehouses(e.toString())),
          ),
        ),
        data: (warehouses) =>
            _Body(draft: draft, warehouses: warehouses),
      ),
      floatingActionButton: draft.lines.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: Text(context.l10n.queueCount),
              onPressed:
                  draft.isSubmittable ? () => _submit(context, ref, draft) : null,
            ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReconciliationDraft draft,
  ) async {
    final settings = ref.read(settingsNotifierProvider);
    final draftWithCompany = draft.copyWith(company: settings.activeCompany);

    final threshold = settings.reconciliationVarianceThreshold;
    final needsApproval =
        threshold > 0 && draftWithCompany.totalVariance > threshold;

    final initialStatus =
        needsApproval ? OpStatus.pendingApproval : OpStatus.pending;
    final id = await ref
        .read(submitReconciliationUseCaseProvider)
        .callWithStatus(draftWithCompany, initialStatus);

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

  const _Body({required this.draft, required this.warehouses});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(reconciliationDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('warehouse-${widget.draft.warehouse}'),
          initialValue: widget.draft.warehouse,
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
                  : () => _startScanSession(context, widget.draft.warehouse!),
            ),
          ],
        ),
        if (widget.draft.warehouse == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.pickWarehouseFirst),
          )
        else if (widget.draft.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.scanItemsToCount),
          )
        else
          ...widget.draft.lines.map(
            (line) => _CountTile(
              line: line,
              warehouse: widget.draft.warehouse!,
              onCountChanged: (q) => notifier.setCount(line.itemCode, q),
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
    final result = await context
        .push<List<ScannedItem>>('/scan-session?mode=reconcile');
    if (result == null || result.isEmpty || !context.mounted) return;

    // Prefetch expected qty for all scanned items concurrently.
    final expectedFutures = result
        .map((s) => ref.read(
              expectedQtyProvider(BinKey(s.item.itemCode, warehouse)).future,
            ),)
        .toList();
    final expectedQtys = await Future.wait(expectedFutures);
    if (!mounted) return;

    final notifier = ref.read(reconciliationDraftProvider.notifier);
    for (var i = 0; i < result.length; i++) {
      final scanned = result[i];
      notifier.addLine(CountLine(
        itemCode: scanned.item.itemCode,
        itemName: scanned.item.itemName,
        countedQty: scanned.qty,
        expectedQty: expectedQtys[i],
      ),);
    }
  }
}

class _CountTile extends ConsumerWidget {
  final CountLine line;
  final String warehouse;
  final ValueChanged<double> onCountChanged;
  final VoidCallback onRemove;

  const _CountTile({
    required this.line,
    required this.warehouse,
    required this.onCountChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final variance = line.variance;
    String? subtitle;
    Color? subtitleColor;
    if (line.itemName != null && line.expectedQty != null) {
      subtitle = '${line.itemName} · Expected ${_fmt(line.expectedQty!)} · Variance ${_fmt(variance!)}';
      if (variance > 0) {
        subtitleColor = scheme.tertiary;
      } else if (variance < 0) {
        subtitleColor = scheme.error;
      }
    } else if (line.itemName != null) {
      subtitle = line.itemName;
    } else if (line.expectedQty != null) {
      subtitle = 'Expected ${_fmt(line.expectedQty!)} · Variance ${_fmt(variance!)}';
      if (variance > 0) {
        subtitleColor = scheme.tertiary;
      } else if (variance < 0) {
        subtitleColor = scheme.error;
      }
    }
    return ListTile(
      title: Text(line.itemCode),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: subtitleColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: _fmt(line.countedQty),
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null && q >= 0) onCountChanged(q);
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

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
