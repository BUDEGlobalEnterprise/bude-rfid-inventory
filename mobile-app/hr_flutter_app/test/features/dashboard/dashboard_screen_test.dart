import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/authentication/data/auth_repository.dart';
import 'package:bude_hr/features/authentication/presentation/auth_controller.dart';
import 'package:bude_hr/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hides the manager section for a normal employee', (
    tester,
  ) async {
    await _pumpDashboard(tester, roles: const ['Employee']);

    expect(find.text('Manager tools'), findsNothing);
  });

  testWidgets('shows the manager section for an HR manager', (tester) async {
    await _pumpDashboard(tester, roles: const ['HR Manager']);

    expect(find.text('Manager tools'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<String> roles,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = _FakeSessionStore();
  final session = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'employee@example.com',
    fullName: 'Test Employee',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: roles,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureSessionStoreProvider.overrideWithValue(store),
        authControllerProvider.overrideWith(
          (ref) => _FixedAuthController(session, store),
        ),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FixedAuthController extends AuthController {
  _FixedAuthController(HrSession session, SecureSessionStore store)
      : super(_NoopAuthRepository(store), store) {
    state = AuthState(session: session, isRestoring: false);
  }
}

class _NoopAuthRepository extends AuthRepository {
  _NoopAuthRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}
