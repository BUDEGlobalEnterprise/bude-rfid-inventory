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
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncEngineProvider).kick(),
          ),
        ],
      ),
      body: opsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ops) {
          final unresolved = ops
              .where((o) => o.status != OpStatus.succeeded)
              .toList();
          if (unresolved.isEmpty) {
            return Center(
              child: Text(context.l10n.emptyQueue),
            );
          }
          return ListView.separated(
            itemCount: unresolved.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) => _OpTile(op: unresolved[i]),
          );
        },
      ),
    );
  }
}

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
      // Pending uses the muted variant slot — it's "neutral, waiting"
      // rather than "alert, attention".
      OpStatus.pending => Icon(Icons.schedule, color: scheme.outline),
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
