import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/utils/locale_ext.dart';

class PendingQueueScreen extends ConsumerWidget {
  const PendingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(allOpsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.syncAndOffline),
        actions: [
          // Retry all failed ops in one tap.
          opsAsync.whenOrNull(
                data: (ops) {
                  final failed =
                      ops.where((o) => o.status == OpStatus.failed).toList();
                  if (failed.isEmpty) return null;
                  return IconButton(
                    tooltip: 'Retry all failed',
                    icon: const Icon(Icons.replay),
                    onPressed: () async {
                      final queue = ref.read(syncQueueProvider);
                      for (final op in failed) {
                        await queue.retry(op.id);
                      }
                      await ref.read(syncEngineProvider).kick();
                    },
                  );
                },
              ) ??
              const SizedBox.shrink(),
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncEngineProvider).kick(),
          ),
          // Clear all succeeded ops.
          opsAsync.whenOrNull(
                data: (ops) {
                  final done =
                      ops.where((o) => o.status == OpStatus.succeeded).toList();
                  if (done.isEmpty) return null;
                  return PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'clear') {
                        final queue = ref.read(syncQueueProvider);
                        for (final op in done) {
                          await queue.delete(op.id);
                        }
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ops) {
          final unresolved =
              ops.where((o) => o.status != OpStatus.succeeded).toList();

          final pending =
              unresolved.where((o) => o.status == OpStatus.pending).length;
          final inflight =
              unresolved.where((o) => o.status == OpStatus.inflight).length;
          final failed =
              unresolved.where((o) => o.status == OpStatus.failed).length;
          final succeeded =
              ops.where((o) => o.status == OpStatus.succeeded).toList();
          final lastSyncOp = succeeded.isEmpty
              ? null
              : succeeded
                  .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);

          return Column(
            children: [
              _SyncSummary(
                pending: pending,
                inflight: inflight,
                failed: failed,
                lastSyncTime: lastSyncOp?.createdAt,
              ),
              Expanded(
                child: unresolved.isEmpty
                    ? Center(child: Text(context.l10n.emptyQueue))
                    : ListView.separated(
                        itemCount: unresolved.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) =>
                            _OpTile(op: unresolved[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SyncSummary extends StatelessWidget {
  final int pending;
  final int inflight;
  final int failed;
  final DateTime? lastSyncTime;

  const _SyncSummary({
    required this.pending,
    required this.inflight,
    required this.failed,
    required this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastSync = lastSyncTime == null
        ? '—'
        : DateFormat.MMMd().add_jm().format(lastSyncTime!.toLocal());

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _Chip(label: '$pending pending', color: scheme.outline),
          const SizedBox(width: 8),
          if (inflight > 0) ...[
            _Chip(label: '$inflight syncing', color: scheme.primary),
            const SizedBox(width: 8),
          ],
          if (failed > 0) ...[
            _Chip(label: '$failed failed', color: scheme.error),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          Text(
            'Last sync: $lastSync',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Op tile ───────────────────────────────────────────────────────────────────

class _OpTile extends ConsumerWidget {
  final PendingOperation op;
  const _OpTile({required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat.yMMMd().add_jm();
    return ListTile(
      leading: _StatusIcon(status: op.status),
      title: Text(op.type),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Created ${fmt.format(op.createdAt.toLocal())}'),
          if (op.attempts > 0) Text('Attempts: ${op.attempts}'),
          if (op.lastError != null) ErrorText(op.lastError!),
        ],
      ),
      isThreeLine: op.lastError != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (op.status == OpStatus.pendingApproval)
            ActionChip(
              avatar: const Icon(Icons.approval, size: 16),
              label: const Text('Approve'),
              onPressed: () => context.push('/reconcile/approve', extra: op.id),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final queue = ref.read(syncQueueProvider);
              if (value == 'retry') {
                await queue.retry(op.id);
                await ref.read(syncEngineProvider).kick();
              } else if (value == 'discard') {
                await queue.delete(op.id);
              }
            },
            itemBuilder: (_) => [
              if (op.status == OpStatus.failed)
                const PopupMenuItem(value: 'retry', child: Text('Retry')),
              const PopupMenuItem(value: 'discard', child: Text('Discard')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final OpStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      OpStatus.pending => Icon(Icons.schedule, color: scheme.outline),
      OpStatus.pendingApproval => Icon(Icons.approval, color: scheme.primary),
      OpStatus.inflight => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      OpStatus.failed => Icon(Icons.error, color: scheme.error),
      OpStatus.succeeded => Icon(Icons.check_circle, color: scheme.tertiary),
    };
  }
}
