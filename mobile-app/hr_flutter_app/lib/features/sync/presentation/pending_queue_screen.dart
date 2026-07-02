import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/pending_operation.dart';
import 'sync_controller.dart';

class PendingQueueScreen extends ConsumerWidget {
  const PendingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending sync'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: state.isSyncing ? null : controller.syncAll,
            icon: state.isSyncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: state.operations.isEmpty
                ? const Center(child: Text('Nothing waiting to sync.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final op in state.operations)
                        Card(
                          child: ListTile(
                            leading: Icon(_iconFor(op.type)),
                            title: Text(op.label),
                            subtitle: Text(_since(op.createdAt)),
                            trailing: IconButton(
                              tooltip: 'Discard',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => controller.discard(op.id),
                            ),
                            onTap: () => _showDetail(context, op),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(PendingOperationType type) => switch (type) {
        PendingOperationType.attendanceCheckIn => Icons.fingerprint,
        PendingOperationType.expenseDraft => Icons.receipt_long,
      };

  static String _since(DateTime at) => 'Queued ${at.toIso8601String()}';

  void _showDetail(BuildContext context, PendingHrOperation op) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(op.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_since(op.createdAt)),
            const Divider(height: 24),
            for (final entry in op.payload.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${entry.key}: ${entry.value}'),
              ),
          ],
        ),
      ),
    );
  }
}
