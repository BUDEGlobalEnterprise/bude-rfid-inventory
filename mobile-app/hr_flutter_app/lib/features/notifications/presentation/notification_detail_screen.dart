import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import 'notifications_screen.dart';

final notificationDetailProvider =
    FutureProvider.family<HrNotification, String>((ref, name) async {
  final repository = ref.watch(notificationRepositoryProvider);
  final detail = await repository.detail(name);
  // Mark as read on open, then refresh the list so the badge clears.
  if (!detail.read) {
    await repository.markRead(name);
    ref.invalidate(notificationsProvider);
  }
  return detail;
});

class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(notificationDetailProvider(name));
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: detail.when(
        data: (row) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(row.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(row.date, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(row.message),
          ],
        ),
        error: (_, __) =>
            const Center(child: Text('Unable to load this notification.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
