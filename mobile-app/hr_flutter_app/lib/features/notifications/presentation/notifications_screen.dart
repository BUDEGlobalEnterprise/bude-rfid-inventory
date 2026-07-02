import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/widgets/last_refreshed_label.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/notification_repository.dart';
import 'notification_detail_screen.dart';

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
        data: (cached) {
          final rows = cached.data;
          if (rows.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: Column(
              children: [
                LastRefreshedLabel(
                  fetchedAt: cached.fetchedAt,
                  fromCache: cached.fromCache,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final row = rows[index];
                return ListTile(
                  leading: Icon(
                    row.read
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: row.read
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    row.title,
                    style: TextStyle(
                      fontWeight:
                          row.read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    row.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(row.date),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationDetailScreen(name: row.name),
                    ),
                  ),
                );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load notifications.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(notificationsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
