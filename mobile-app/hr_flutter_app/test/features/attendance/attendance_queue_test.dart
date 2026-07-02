import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/pending_operation.dart';
import 'package:bude_hr/core/offline/pending_operations_queue.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/attendance/data/attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const session = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'employee@example.com',
    fullName: 'Test Employee',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: ['Employee'],
  );

  PendingHrOperation checkIn(String id) => PendingHrOperation(
        id: id,
        type: PendingOperationType.attendanceCheckIn,
        payload: const {'type': 'IN'},
        createdAt: DateTime.parse('2026-07-01T09:00:00'),
      );

  test('queues a check-in offline when submit fails', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    final repository = AttendanceRepository(
      _RespondingApiClient(ok: false),
      _FixedSessionStore(session),
      queue,
    );

    await repository.check('IN');

    final pending = await repository.pending();
    expect(pending, hasLength(1));
    expect(pending.single.type, PendingOperationType.attendanceCheckIn);
  });

  test('submits online check-in with optional geofence payload', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    final client = _RespondingApiClient(ok: true);
    final repository = AttendanceRepository(
      client,
      _FixedSessionStore(session),
      queue,
    );

    await repository.check('IN', latitude: 25.2048, longitude: 55.2708);

    expect(await repository.pending(), isEmpty);
    expect(client.lastPostData?['type'], 'IN');
    expect(client.lastPostData?['latitude'], 25.2048);
    expect(client.lastPostData?['longitude'], 55.2708);
  });

  test('parses attendance status metadata when backend returns it', () {
    final status = AttendanceStatus.fromJson({
      'checked_in': true,
      'last_check_in': '2026-07-01 09:00:00',
      'shift_name': 'General',
      'late_entry': true,
      'early_exit': false,
      'holiday_label': 'Weekly Off',
    });

    expect(status.checkedIn, isTrue);
    expect(status.shiftName, 'General');
    expect(status.lateEntry, isTrue);
    expect(status.earlyExit, isFalse);
    expect(status.holidayLabel, 'Weekly Off');
  });

  test('retryPending clears a check-in once it syncs', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(checkIn('a-1'));
    final repository = AttendanceRepository(
      _RespondingApiClient(ok: true),
      _FixedSessionStore(session),
      queue,
    );

    final error = await repository.retryPending();

    expect(error, isNull);
    expect(await repository.pending(), isEmpty);
  });

  test('retryPending keeps a check-in when the sync still fails', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(checkIn('a-1'));
    final repository = AttendanceRepository(
      _RespondingApiClient(ok: false),
      _FixedSessionStore(session),
      queue,
    );

    final error = await repository.retryPending();

    expect(error, isNotNull);
    expect(await repository.pending(), hasLength(1));
  });

  test('parses attendance history rows', () {
    final row = AttendanceHistoryRow.fromJson({
      'name': 'CHK-001',
      'log_type': 'IN',
      'time': '2026-07-01 09:00:00',
    });

    expect(row.name, 'CHK-001');
    expect(row.logType, 'IN');
    expect(row.time, '2026-07-01 09:00:00');
  });
}

class _FixedSessionStore extends SecureSessionStore {
  _FixedSessionStore(this._session);

  final HrSession _session;

  @override
  Future<HrSession?> read() async => _session;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _RespondingApiClient extends HrApiClient {
  _RespondingApiClient({required this.ok})
      : super(_FixedSessionStore(_dummySession));

  final bool ok;
  Map<String, dynamic>? lastPostData;

  static const _dummySession = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'employee@example.com',
    fullName: 'Test Employee',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: ['Employee'],
  );

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    lastPostData = data;
    return ok ? {'ok': true} : {'ok': false, 'message': 'Server error.'};
  }
}
