import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/utils/locale_ext.dart';
import '../domain/audit_operation_summary.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

// Sentinel for "All" filter (empty string, not null, so SegmentedButton<String> works).
const _kFilterAll = '';
const _kFilterApproval = '__approval__';
const _kFilterFailed = '__failed__';

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
                    : ops.where((o) {
                        if (_typeFilter == _kFilterApproval) {
                          return o.status == OpStatus.pendingApproval;
                        }
                        if (_typeFilter == _kFilterFailed) {
                          return o.status == OpStatus.failed;
                        }
                        return o.type == _typeFilter;
                      }).toList();
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
            value: _kFilterApproval,
            label: const Text('Approval'),
          ),
          ButtonSegment(
            value: _kFilterFailed,
            label: const Text('Failed'),
          ),
          ButtonSegment(
            value: kStockTransferAuditType,
            label: Text(context.l10n.stockTransferLabel),
          ),
          ButtonSegment(
            value: kStockReceiptAuditType,
            label: Text(context.l10n.goodsReceiptLabel),
          ),
          ButtonSegment(
            value: kStockReconciliationAuditType,
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
    final summary = summarizeOperation(op);
    final erpUrl = _buildErpUrl(tenantUrl, op);

    return ListTile(
      leading: Icon(_typeIcon(op.type)),
      title: Text(summary.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.subtitle),
          Text(fmt.format(op.createdAt.toLocal())),
          Text('Op ${op.id}', style: Theme.of(context).textTheme.bodySmall),
          if (op.attempts > 0) Text('Attempts: ${op.attempts}'),
          if (op.lastError != null && op.lastError!.isNotEmpty)
            Text('Error: ${op.lastError}'),
          if (summary.approvalReason != null)
            Text('Approval: ${summary.approvalReason}'),
          if (summary.approvedBy != null)
            Text('Approved by: ${summary.approvedBy}'),
          if (summary.approvedAt != null)
            Text('Approved at: ${summary.approvedAt}'),
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
      isThreeLine: true,
      trailing: _StatusChip(status: op.status),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
        kStockTransferAuditType => Icons.swap_horiz,
        kStockReceiptAuditType => Icons.input,
        kStockReconciliationAuditType => Icons.fact_check,
        _ => Icons.sync,
      };

  String? _buildErpUrl(String? base, PendingOperation op) {
    if (base == null || op.serverRef == null) return null;
    final segment = erpRouteSegmentForOperation(op.type);
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
