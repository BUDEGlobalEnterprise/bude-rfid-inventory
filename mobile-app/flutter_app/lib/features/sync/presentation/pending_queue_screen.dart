import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';

class PendingQueueScreen extends ConsumerWidget {
  const PendingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(allOpsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending sync'),
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
            return const Center(
              child: Text('Nothing pending — all caught up.'),
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
          if (op.lastError != null)
            Text(
              op.lastError!,
              style: TextStyle(color: Colors.red.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      isThreeLine: op.lastError != null,
      trailing: PopupMenuButton<String>(
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
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final OpStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      OpStatus.pending =>
        const Icon(Icons.schedule, color: Colors.orange),
      OpStatus.inflight => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      OpStatus.failed => Icon(Icons.error, color: Colors.red.shade700),
      OpStatus.succeeded =>
        const Icon(Icons.check_circle, color: Colors.green),
    };
  }
}
