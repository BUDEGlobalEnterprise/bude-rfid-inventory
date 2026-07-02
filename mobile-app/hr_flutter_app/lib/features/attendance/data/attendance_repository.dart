import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/pending_operation.dart';
import '../../../core/offline/pending_operations_queue.dart';
import '../../../core/storage/secure_session_store.dart';

class AttendanceRepository {
  AttendanceRepository(this._client, this._sessionStore, this._queue);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final PendingOperationsQueue _queue;

  Future<AttendanceStatus> status() async {
    final session = await _requireSession();
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.attendanceStatus,
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map),
    );
    if (!envelope.ok || envelope.data == null) {
      throw Exception(envelope.message ?? 'Unable to load attendance.');
    }
    return AttendanceStatus.fromJson(envelope.data!);
  }

  Future<List<AttendanceHistoryRow>> history({int limit = 30}) async {
    final session = await _requireSession();
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.attendanceHistory,
      query: {'limit': limit},
    );
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    if (!envelope.ok) {
      throw Exception(envelope.message ?? 'Unable to load attendance history.');
    }
    return (envelope.data ?? const [])
        .map(
          (row) => AttendanceHistoryRow.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> check(
    String type, {
    double? latitude,
    double? longitude,
  }) async {
    final session = await _requireSession();
    try {
      await _submitCheckin(
        session,
        type,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      final now = DateTime.now();
      await _queue.enqueue(
        PendingHrOperation(
          id: now.microsecondsSinceEpoch.toString(),
          type: PendingOperationType.attendanceCheckIn,
          payload: {'type': type},
          createdAt: now,
        ),
      );
    }
  }

  Future<List<PendingHrOperation>> pending() =>
      _queue.readByType(PendingOperationType.attendanceCheckIn);

  /// Retries every queued check-in against the API; synced ops are removed
  /// and the message from the last op that still fails is returned, if any.
  Future<String?> retryPending() async {
    final session = await _sessionStore.read();
    if (session == null) return 'Not signed in.';
    String? lastError;
    for (final op in await pending()) {
      final type = op.payload['type'] as String? ?? 'IN';
      try {
        await _submitCheckin(session, type);
        await _queue.discard(op.id);
      } catch (_) {
        lastError =
            'Unable to sync a pending ${type == 'IN' ? 'check-in' : 'check-out'}.';
      }
    }
    return lastError;
  }

  Future<void> discardPending() =>
      _queue.clearType(PendingOperationType.attendanceCheckIn);

  Future<void> _submitCheckin(
    HrSession session,
    String type, {
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{'type': type};
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }
    final response = await _client.post(
      session.baseUrl,
      HrApiEndpoints.checkIn,
      data: data,
    );
    final envelope = ApiEnvelope<Object?>.fromJson(response, (value) => value);
    if (!envelope.ok) throw Exception(envelope.message);
  }

  Future<HrSession> _requireSession() async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    return session;
  }
}

class AttendanceHistoryRow {
  final String name;
  final String logType;
  final String time;

  const AttendanceHistoryRow({
    required this.name,
    required this.logType,
    required this.time,
  });

  factory AttendanceHistoryRow.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryRow(
      name: json['name'] as String? ?? '',
      logType: json['log_type'] as String? ?? '',
      time: json['time'] as String? ?? '',
    );
  }
}

class AttendanceStatus {
  final bool checkedIn;
  final String? lastCheckIn;
  final String? lastCheckOut;
  final String? shiftName;
  final bool lateEntry;
  final bool earlyExit;
  final String? holidayLabel;

  const AttendanceStatus({
    required this.checkedIn,
    this.lastCheckIn,
    this.lastCheckOut,
    this.shiftName,
    this.lateEntry = false,
    this.earlyExit = false,
    this.holidayLabel,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      checkedIn: json['checked_in'] == true,
      lastCheckIn: json['last_check_in'] as String?,
      lastCheckOut: json['last_check_out'] as String?,
      shiftName: json['shift_name'] as String?,
      lateEntry: json['late_entry'] == true,
      earlyExit: json['early_exit'] == true,
      holidayLabel: json['holiday_label'] as String?,
    );
  }
}
