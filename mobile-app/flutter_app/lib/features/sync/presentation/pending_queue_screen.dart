import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../labels/domain/label_request_builders.dart';

class PendingQueueScreen extends ConsumerWidget {
  const PendingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(allOpsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.syncAndOffline),
        actions: [
          opsAsync.whenOrNull(
                data: (ops) {
                  final failed =
                      ops.where((o) => o.status == OpStatus.failed).toList();
                  if (failed.isEmpty) return null;
                  return IconButton(
                    tooltip: 'Retry all failed',
                    icon: const Icon(Icons.replay),
                    onPressed: () => _retryAll(ref, failed),
                  );
                },
              ) ??
              const SizedBox.shrink(),
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncEngineProvider).kick(),
          ),
          opsAsync.whenOrNull(
                data: (ops) {
                  final done =
                      ops.where((o) => o.status == OpStatus.succeeded).toList();
                  if (done.isEmpty) return null;
                  return PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'clear') {
                        await _clearCompleted(ref, done);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear completed (${done.length})'),
                      ),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: opsAsync.when(
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ops) => _QueueContent(ops: ops),
      ),
    );
  }

  static Future<void> _retryAll(
    WidgetRef ref,
    List<PendingOperation> failed,
  ) async {
    final queue = ref.read(syncQueueProvider);
    for (final op in failed) {
      await queue.retry(op.id);
    }
    await ref.read(syncEngineProvider).kick();
  }

  static Future<void> _clearCompleted(
    WidgetRef ref,
    List<PendingOperation> done,
  ) async {
    final queue = ref.read(syncQueueProvider);
    for (final op in done) {
      await queue.delete(op.id);
    }
  }
}

class _QueueContent extends ConsumerWidget {
  final List<PendingOperation> ops;
  const _QueueContent({required this.ops});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...ops]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final approval =
        sorted.where((o) => o.status == OpStatus.pendingApproval).toList();
    final failed = sorted.where((o) => o.status == OpStatus.failed).toList();
    final inflight =
        sorted.where((o) => o.status == OpStatus.inflight).toList();
    final pending = sorted.where((o) => o.status == OpStatus.pending).toList();
    final succeeded =
        sorted.where((o) => o.status == OpStatus.succeeded).toList();
    final unresolved =
        approval.length + failed.length + inflight.length + pending.length;

    return RefreshIndicator(
      onRefresh: () async => ref.read(syncEngineProvider).kick(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SyncSummary(
            pendingApproval: approval.length,
            pending: pending.length,
            inflight: inflight.length,
            failed: failed.length,
            completed: succeeded.length,
            lastSyncTime: succeeded.isEmpty ? null : succeeded.first.createdAt,
            onSyncNow: () => ref.read(syncEngineProvider).kick(),
          ),
          const SizedBox(height: 16),
          if (unresolved == 0)
            EmptyStateView(
              icon: Icons.cloud_done_outlined,
              title: context.l10n.emptyQueue,
              subtitle: context.l10n.emptyQueueSubtitle,
              action: OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
                onPressed: () => ref.read(syncEngineProvider).kick(),
              ),
            )
          else ...[
            if (approval.isNotEmpty)
              _QueueSection(
                title: 'Needs approval',
                icon: Icons.approval_outlined,
                ops: approval,
              ),
            if (failed.isNotEmpty)
              _QueueSection(
                title: 'Failed',
                icon: Icons.error_outline,
                ops: failed,
              ),
            if (inflight.isNotEmpty)
              _QueueSection(
                title: 'Syncing now',
                icon: Icons.sync,
                ops: inflight,
              ),
            if (pending.isNotEmpty)
              _QueueSection(
                title: 'Waiting to sync',
                icon: Icons.schedule,
                ops: pending,
              ),
          ],
          if (succeeded.isNotEmpty) ...[
            const SizedBox(height: 12),
            _QueueSection(
              title: 'Recently completed',
              icon: Icons.check_circle_outline,
              ops: succeeded.take(5).toList(),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncSummary extends StatelessWidget {
  final int pendingApproval;
  final int pending;
  final int inflight;
  final int failed;
  final int completed;
  final DateTime? lastSyncTime;
  final VoidCallback onSyncNow;

  const _SyncSummary({
    required this.pendingApproval,
    required this.pending,
    required this.inflight,
    required this.failed,
    required this.completed,
    required this.lastSyncTime,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastSync = lastSyncTime == null
        ? 'Never'
        : DateFormat.MMMd().add_jm().format(lastSyncTime!.toLocal());

    return BudeOperationHeader(
      icon: failed > 0 ? Icons.sync_problem : Icons.cloud_sync_outlined,
      title: context.l10n.syncAndOffline,
      subtitle: 'Offline work is queued here until ERPNext accepts it.',
      pills: [
        BudeSummaryPill(
          icon: Icons.schedule,
          label: 'Waiting',
          value: '$pending',
        ),
        if (pendingApproval > 0)
          BudeSummaryPill(
            icon: Icons.approval_outlined,
            label: 'Approval',
            value: '$pendingApproval',
          ),
        if (inflight > 0)
          BudeSummaryPill(
            icon: Icons.sync,
            label: 'Syncing',
            value: '$inflight',
          ),
        BudeSummaryPill(
          icon: failed > 0 ? Icons.error_outline : Icons.check_circle_outline,
          label: 'Failed',
          value: '$failed',
        ),
        BudeStatusChip(
          label: 'Last sync $lastSync',
          icon: Icons.history,
          color: failed > 0 ? scheme.error : scheme.primary,
        ),
        BudeStatusChip(
          label: '$completed completed',
          icon: Icons.done_all,
          color: scheme.secondary,
        ),
        ActionChip(
          avatar: const Icon(Icons.sync, size: 16),
          label: const Text('Sync now'),
          onPressed: onSyncNow,
        ),
      ],
    );
  }
}

class _QueueSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<PendingOperation> ops;
  final bool compact;

  const _QueueSection({
    required this.title,
    required this.icon,
    required this.ops,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '$title (${ops.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          for (final op in ops)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OpCard(op: op, compact: compact),
            ),
        ],
      ),
    );
  }
}

class _OpCard extends ConsumerWidget {
  final PendingOperation op;
  final bool compact;

  const _OpCard({required this.op, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat.MMMd().add_jm();
    final spec = _operationSpec(op);

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusIcon(status: op.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.subtitle,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BudeStatusChip(
                  label: _statusLabel(op.status),
                  icon: _statusBadgeIcon(op.status),
                  color: _statusColor(context, op.status),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BudeStatusChip(
                    label: 'Created ${fmt.format(op.createdAt.toLocal())}',
                    icon: Icons.schedule,
                    color: scheme.primary,
                  ),
                  if (op.attempts > 0)
                    BudeStatusChip(
                      label: '${op.attempts} attempts',
                      icon: Icons.repeat,
                      color: scheme.tertiary,
                    ),
                  if (op.nextRetryAt != null)
                    BudeStatusChip(
                      label: 'Retry ${fmt.format(op.nextRetryAt!.toLocal())}',
                      icon: Icons.timer_outlined,
                      color: scheme.tertiary,
                    ),
                  if (op.serverRef != null && op.serverRef!.isNotEmpty)
                    BudeStatusChip(
                      label: op.serverRef!,
                      icon: Icons.link,
                      color: scheme.secondary,
                    ),
                ],
              ),
              if (op.lastError != null) ...[
                const SizedBox(height: 10),
                ErrorText(op.lastError!, maxLines: 3),
              ],
              if (_string(op.payload['approval_reason']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Approval: ${_string(op.payload['approval_reason'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              _OpActions(op: op),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpActions extends ConsumerWidget {
  final PendingOperation op;
  const _OpActions({required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[
      if (op.status == OpStatus.pendingApproval)
        FilledButton.tonalIcon(
          icon: const Icon(Icons.approval_outlined),
          label: const Text('Approve'),
          onPressed: () => context.push('/reconcile/approve', extra: op.id),
        ),
      if (op.status == OpStatus.failed)
        FilledButton.tonalIcon(
          icon: const Icon(Icons.replay),
          label: const Text('Retry'),
          onPressed: () async {
            await ref.read(syncQueueProvider).retry(op.id);
            await ref.read(syncEngineProvider).kick();
          },
        ),
      if (op.type == 'stock_receipt')
        TextButton.icon(
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print label'),
          onPressed: () => context.push(
            '/labels',
            extra: receiptLabelRequestFromOperation(op),
          ),
        ),
      if (op.status != OpStatus.inflight)
        TextButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Discard'),
          onPressed: () => _confirmDiscard(context, ref, op),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    WidgetRef ref,
    PendingOperation op,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard operation?'),
        content: const Text(
          'This removes the queued work from this device. It will not sync to ERPNext.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncQueueProvider).delete(op.id);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final OpStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    final icon = switch (status) {
      OpStatus.pending => Icons.schedule,
      OpStatus.pendingApproval => Icons.approval_outlined,
      OpStatus.inflight => Icons.sync,
      OpStatus.failed => Icons.error_outline,
      OpStatus.succeeded => Icons.check_circle_outline,
    };

    if (status == OpStatus.inflight) {
      return SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _OperationSpec {
  final String title;
  final String subtitle;

  const _OperationSpec(this.title, this.subtitle);
}

_OperationSpec _operationSpec(PendingOperation op) {
  final payload = op.payload;
  final lineKey = payload['items'] is List
      ? 'items'
      : (payload['counts'] is List ? 'counts' : null);
  final lines = lineKey == null ? const [] : payload[lineKey] as List;
  final totalQty = lines.fold<double>(0, (sum, raw) {
    if (raw is! Map) return sum;
    final value = raw['qty'];
    return sum + (value is num ? value.toDouble() : 0);
  });
  final qtySummary = lines.isEmpty
      ? ''
      : '${lines.length} line${lines.length == 1 ? '' : 's'}'
          ' / qty ${formatOperationalQty(totalQty)}';
  final tracking = _trackingSummary(lines);

  return switch (op.type) {
    'stock_transfer' => _OperationSpec(
        'Stock transfer',
        [
          _arrow(
            _warehouseWithLocation(
              payload['source_warehouse'],
              payload['source_location'],
            ),
            _warehouseWithLocation(
              payload['target_warehouse'],
              payload['target_location'],
            ),
          ),
          qtySummary,
          tracking,
          _company(payload),
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'stock_receipt' => _OperationSpec(
        'Goods receipt',
        [
          _target(
            _warehouseWithLocation(
              payload['target_warehouse'],
              payload['target_location'],
            ),
          ),
          if ((payload['against_po'] as String?)?.isNotEmpty == true)
            'PO ${payload['against_po']}',
          qtySummary,
          tracking,
          _company(payload),
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'stock_reconciliation' => _OperationSpec(
        'Stock count',
        [
          _target(
            _warehouseWithLocation(payload['warehouse'], payload['location']),
          ),
          qtySummary,
          tracking,
          _company(payload),
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'sales_order_dispatch' => _OperationSpec(
        'Sales Order dispatch',
        [
          _target(payload['sales_order']),
          _string(payload['customer']),
          _target(
            _warehouseWithLocation(
              payload['source_warehouse'],
              payload['source_location'],
            ),
          ),
          qtySummary,
          tracking,
          _company(payload),
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'asset_movement' => _OperationSpec(
        'Asset movement',
        [
          _string(payload['purpose']),
          _assetCount(payload['assets']),
          _target(payload['target_location']),
          if (_string(payload['to_employee']).isNotEmpty)
            'Employee ${payload['to_employee']}',
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'asset_repair' => _OperationSpec(
        'Asset repair',
        [
          _target(payload['asset']),
          if (_string(payload['repair_cost']).isNotEmpty)
            'Cost ${payload['repair_cost']}',
        ].where((v) => v.isNotEmpty).join(' - '),
      ),
    'maintenance_log' => _OperationSpec(
        'Maintenance log',
        _target(payload['log']),
      ),
    _ => _OperationSpec(op.type, op.id),
  };
}

String _statusLabel(OpStatus status) => switch (status) {
      OpStatus.pendingApproval => 'Approval',
      OpStatus.pending => 'Waiting',
      OpStatus.inflight => 'Syncing',
      OpStatus.failed => 'Failed',
      OpStatus.succeeded => 'Done',
    };

IconData _statusBadgeIcon(OpStatus status) => switch (status) {
      OpStatus.pendingApproval => Icons.approval_outlined,
      OpStatus.pending => Icons.schedule,
      OpStatus.inflight => Icons.sync,
      OpStatus.failed => Icons.error_outline,
      OpStatus.succeeded => Icons.check_circle_outline,
    };

Color _statusColor(BuildContext context, OpStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    OpStatus.pendingApproval => scheme.primary,
    OpStatus.pending => scheme.outline,
    OpStatus.inflight => scheme.primary,
    OpStatus.failed => scheme.error,
    OpStatus.succeeded => scheme.secondary,
  };
}

String _string(Object? value) => value?.toString().trim() ?? '';

String _arrow(Object? from, Object? to) {
  final start = _string(from);
  final end = _string(to);
  if (start.isEmpty && end.isEmpty) return '';
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return '$start -> $end';
}

String _target(Object? value) {
  final text = _string(value);
  return text.isEmpty ? '' : text;
}

String _warehouseWithLocation(Object? warehouse, Object? location) {
  final parent = _string(warehouse);
  final child = _string(location);
  if (child.isEmpty || child == parent) return parent;
  if (parent.isEmpty) return child;
  return '$parent / $child';
}

String _company(Map<String, dynamic> payload) {
  final text = _string(payload['company']);
  return text.isEmpty ? '' : text;
}

String _assetCount(Object? value) {
  if (value is! List || value.isEmpty) return '';
  return '${value.length} asset${value.length == 1 ? '' : 's'}';
}

String _trackingSummary(List lines) {
  final parts = <String>[];
  for (final raw in lines) {
    if (raw is! Map) continue;
    final allocations = raw['allocations'];
    if (allocations is! List) continue;
    for (final allocation in allocations) {
      if (allocation is! Map) continue;
      final batch = _string(allocation['batch_no']);
      if (batch.isNotEmpty) parts.add('Batch $batch');
      final serials = allocation['serial_nos'];
      if (serials is List && serials.isNotEmpty) {
        parts.add('${serials.length} serial${serials.length == 1 ? '' : 's'}');
      }
      final expiry = _string(allocation['expiry_date']);
      if (expiry.isNotEmpty) parts.add('Exp $expiry');
    }
  }
  if (parts.isEmpty) return '';
  return parts.take(4).join(' / ');
}
