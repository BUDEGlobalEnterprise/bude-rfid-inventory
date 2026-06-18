import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/utils/locale_ext.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

const _kTransferType = 'stock_transfer';
const _kReceiptType = 'stock_receipt';
const _kReconciliationType = 'stock_reconciliation';

// Sentinel for "All" filter (empty string, not null, so SegmentedButton<String> works).
const _kFilterAll = '';

class AuditTrailScreen extends ConsumerStatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  String _typeFilter = _kFilterAll;

  @override
  Widget build(BuildContext context) {
    final opsAsync = ref.watch(allOpsProvider);
    final tenantState = ref.watch(tenantNotifierProvider);
    final tenantUrl =
        tenantState is TenantActive ? tenantState.tenant.erpUrl : null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.auditTrail)),
      body: Column(
        children: [
          _FilterBar(
            selected: _typeFilter,
            onSelected: (v) => setState(() => _typeFilter = v),
          ),
          Expanded(
            child: opsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (ops) {
                final filtered = _typeFilter == _kFilterAll
                    ? ops
                    : ops.where((o) => o.type == _typeFilter).toList();
                final sorted = [...filtered]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (sorted.isEmpty) {
                  return _EmptyState();
                }
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) => _AuditTile(
                    op: sorted[i],
                    tenantUrl: tenantUrl,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: _kFilterAll, label: Text(context.l10n.all)),
          ButtonSegment(
            value: _kTransferType,
            label: Text(context.l10n.stockTransferLabel),
          ),
          ButtonSegment(
            value: _kReceiptType,
            label: Text(context.l10n.goodsReceiptLabel),
          ),
          ButtonSegment(
            value: _kReconciliationType,
            label: Text(context.l10n.stockCountLabel),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onSelected(s.first),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noAuditOps,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.noAuditOpsSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final PendingOperation op;
  final String? tenantUrl;

  const _AuditTile({required this.op, required this.tenantUrl});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    final label = _typeLabel(context, op.type);
    final erpUrl = _buildErpUrl(tenantUrl, op);

    return ListTile(
      leading: Icon(_typeIcon(op.type)),
      title: Text(label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmt.format(op.createdAt.toLocal())),
          if (op.attempts > 0) Text('Attempts: ${op.attempts}'),
          if (erpUrl != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => launchUrl(
                Uri.parse(erpUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(context.l10n.viewInErp),
            ),
        ],
      ),
      isThreeLine: op.attempts > 0 || erpUrl != null,
      trailing: _StatusChip(status: op.status),
    );
  }

  String _typeLabel(BuildContext context, String type) => switch (type) {
        _kTransferType => context.l10n.stockTransferLabel,
        _kReceiptType => context.l10n.goodsReceiptLabel,
        _kReconciliationType => context.l10n.stockCountLabel,
        _ => type,
      };

  IconData _typeIcon(String type) => switch (type) {
        _kTransferType => Icons.swap_horiz,
        _kReceiptType => Icons.input,
        _kReconciliationType => Icons.fact_check,
        _ => Icons.sync,
      };

  String? _buildErpUrl(String? base, PendingOperation op) {
    if (base == null || op.serverRef == null) return null;
    final segment = switch (op.type) {
      _kTransferType => 'stock-entry',
      _kReceiptType => 'purchase-receipt',
      _kReconciliationType => 'stock-reconciliation',
      _ => null,
    };
    if (segment == null) return null;
    return '$base/app/$segment/${op.serverRef}';
  }
}

class _StatusChip extends StatelessWidget {
  final OpStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      OpStatus.succeeded => ('Synced', scheme.tertiary),
      OpStatus.failed => ('Failed', scheme.error),
      OpStatus.inflight => ('Syncing', scheme.primary),
      OpStatus.pendingApproval => ('Approval', scheme.secondary),
      OpStatus.pending => ('Pending', scheme.outline),
    };
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
