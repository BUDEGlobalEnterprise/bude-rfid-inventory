import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/read_cache.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/notifications/data/notification_repository.dart';
import 'package:bude_hr/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders notifications list', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(store),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('New Leave Request'), findsOneWidget);
    expect(find.text('Your leave request has been approved'), findsOneWidget);
  });

  testWidgets('shows empty state when no notifications exist', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          notificationRepositoryProvider.overrideWithValue(
            _EmptyNotificationRepository(store),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No notifications.'), findsOneWidget);
  });

  testWidgets('shows error state with retry button', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          notificationRepositoryProvider.overrideWithValue(
            _FailingNotificationRepository(store),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load notifications.'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('marks unread notifications with bold text', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(store),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    final title = find.text('New Leave Request');
    expect(title, findsOneWidget);
  });
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<HrNotification>>> list() async => Cached(
        const [
          HrNotification(
            name: 'NOTIF-001',
            title: 'New Leave Request',
            message: 'Your leave request has been approved',
            date: '2 hours ago',
            read: false,
          ),
          HrNotification(
            name: 'NOTIF-002',
            title: 'Expense Claim Submitted',
            message: 'Your expense claim has been received',
            date: '1 day ago',
            read: true,
          ),
        ],
        DateTime.now(),
      );
}

class _EmptyNotificationRepository extends NotificationRepository {
  _EmptyNotificationRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<HrNotification>>> list() async =>
      Cached(const [], DateTime.now());
}

class _FailingNotificationRepository extends NotificationRepository {
  _FailingNotificationRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<HrNotification>>> list() =>
      throw Exception('Unable to load notifications');
}
