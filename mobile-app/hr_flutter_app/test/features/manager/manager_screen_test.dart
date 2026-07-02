import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/router/app_router.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/authentication/data/auth_repository.dart';
import 'package:bude_hr/features/authentication/presentation/auth_controller.dart';
import 'package:bude_hr/features/manager/data/manager_repository.dart';
import 'package:bude_hr/features/manager/presentation/manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders pending leave approvals for a manager', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          managerRepositoryProvider.overrideWithValue(
            _FakeManagerRepository(store),
          ),
        ],
        child: const MaterialApp(home: ManagerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Bob Employee'), findsOneWidget);
  });

  test('parses manager direct report payload', () {
    final report = DirectReport.fromJson({
      'employee': 'EMP-002',
      'employee_name': 'Bob Employee',
      'department': 'Operations',
      'designation': 'Technician',
      'company_email': 'bob@bude.example',
      'cell_number': '+971500000001',
    });

    expect(report.employee, 'EMP-002');
    expect(report.employeeName, 'Bob Employee');
    expect(report.companyEmail, 'bob@bude.example');
  });

  testWidgets('renders direct reports for a manager', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          managerRepositoryProvider.overrideWithValue(
            _FakeManagerRepository(store),
          ),
        ],
        child: const MaterialApp(home: ManagerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Bob Report'), findsOneWidget);
  });

  testWidgets('redirects a normal employee away from /manager', (tester) async {
    final router = await _pumpRouterAs(tester, roles: const ['Employee']);

    router.go('/manager');
    await tester.pumpAndSettle();

    // ManagerScreen's AppBar title is the unique "Manager" text.
    expect(find.text('Manager'), findsNothing);
  });

  testWidgets('lets a manager open /manager', (tester) async {
    final router = await _pumpRouterAs(tester, roles: const ['HR Manager']);

    router.go('/manager');
    await tester.pumpAndSettle();

    expect(find.text('Manager'), findsOneWidget);
  });
}

Future<GoRouter> _pumpRouterAs(
  WidgetTester tester, {
  required List<String> roles,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = _FakeSessionStore();
  final session = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'manager@example.com',
    fullName: 'Manager',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: roles,
  );
  final container = ProviderContainer(
    overrides: [
      secureSessionStoreProvider.overrideWithValue(store),
      authControllerProvider.overrideWith(
        (ref) => _FixedAuthController(session, store),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
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

class _FakeManagerRepository extends ManagerRepository {
  _FakeManagerRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<ManagerSummary> summary() async =>
      const ManagerSummary(pendingLeaves: 1, pendingExpenses: 0);

  @override
  Future<List<PendingLeaveApproval>> pendingLeaves() async => const [
        PendingLeaveApproval(
          name: 'LV-001',
          employeeName: 'Bob Employee',
          leaveType: 'Annual Leave',
          fromDate: '2026-07-10',
          toDate: '2026-07-11',
          totalLeaveDays: 2,
        ),
      ];

  @override
  Future<List<DirectReport>> directReports() async => const [
        DirectReport(
          employee: 'EMP-002',
          employeeName: 'Bob Report',
          department: 'Operations',
          designation: 'Technician',
          companyEmail: 'bob@bude.example',
          cellNumber: '+971500000001',
        ),
      ];

  @override
  Future<List<PendingExpenseApproval>> pendingExpenses() async => const [];
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}
