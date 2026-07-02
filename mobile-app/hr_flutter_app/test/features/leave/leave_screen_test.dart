import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/read_cache.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/leave/data/leave_repository.dart';
import 'package:bude_hr/features/leave/presentation/leave_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders leave requests with a status chip', (tester) async {
    await _pumpLeave(
      tester,
      requests: const [
        LeaveApplication(
          name: 'LV-001',
          leaveType: 'Annual Leave',
          fromDate: '2026-07-10',
          toDate: '2026-07-11',
          status: 'Approved',
          totalLeaveDays: 2,
          description: 'Trip',
          cancellable: true,
        ),
      ],
    );

    expect(find.text('Annual Leave'), findsOneWidget);
    expect(find.widgetWithText(LeaveStatusChip, 'Approved'), findsOneWidget);
  });

  testWidgets('blocks applying without a leave type', (tester) async {
    await _pumpLeave(tester, requests: const []);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Select a leave type.'), findsOneWidget);
  });
}

Future<void> _pumpLeave(
  WidgetTester tester, {
  required List<LeaveApplication> requests,
}) async {
  final store = _FakeSessionStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureSessionStoreProvider.overrideWithValue(store),
        leaveRepositoryProvider.overrideWithValue(
          _FakeLeaveRepository(requests, store),
        ),
      ],
      child: const MaterialApp(home: LeaveScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeLeaveRepository extends LeaveRepository {
  _FakeLeaveRepository(this._requests, SecureSessionStore store)
      : super(HrApiClient(store), store);

  final List<LeaveApplication> _requests;

  @override
  Future<Cached<List<LeaveBalance>>> balances() async => Cached(
        const [
          LeaveBalance(
            leaveType: 'Annual Leave',
            allocated: 20,
            used: 3,
            available: 17,
          ),
        ],
        DateTime(2026, 7, 1),
      );

  @override
  Future<List<LeaveApplication>> requests() async => _requests;

  @override
  Future<void> apply({
    required String leaveType,
    required String fromDate,
    required String toDate,
    String? reason,
    bool halfDay = false,
    String? halfDayDate,
  }) async {}
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}
