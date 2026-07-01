import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final notificationsProvider = FutureProvider((ref) {
  return ref.watch(notificationRepositoryProvider).list();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.when(
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (_, index) {
            final row = rows[index];
            return ListTile(
              title: Text(row.title),
              subtitle: Text(row.message),
              trailing: Text(row.date),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Unable to load notifications.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
