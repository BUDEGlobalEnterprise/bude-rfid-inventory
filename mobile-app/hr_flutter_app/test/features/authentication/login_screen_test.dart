import 'package:bude_hr/app.dart';
import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/authentication/data/auth_repository.dart';
import 'package:bude_hr/features/authentication/presentation/auth_controller.dart';
import 'package:bude_hr/features/authentication/presentation/login_screen.dart';
import 'package:bude_hr/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen validates required fields', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository('Not used', store),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid ERPNext URL.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'erp.example.com');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter username and password.'), findsOneWidget);
  });

  testWidgets('login screen shows repository failure message', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository('Wrong credentials.', store),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'erp.example.com');
    await tester.enterText(find.byType(TextField).at(1), 'employee@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Wrong credentials.'), findsOneWidget);
  });

  testWidgets('successful login navigates to the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(null, store),
          ),
        ],
        child: const BudeHrApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'erp.example.com');
    await tester.enterText(
      find.byType(TextField).at(1),
      'employee@example.com',
    );
    await tester.enterText(find.byType(TextField).at(2), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.message, SecureSessionStore store)
      : super(HrApiClient(store), store);

  /// Null message means login succeeds instead of failing.
  final String? message;

  @override
  Future<HrSession> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    if (message != null) throw AuthFailure(message!);
    return HrSession(
      baseUrl: baseUrl,
      user: username,
      fullName: 'Test Employee',
      apiKey: 'key',
      apiSecret: 'secret',
      roles: const ['Employee'],
    );
  }
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}
