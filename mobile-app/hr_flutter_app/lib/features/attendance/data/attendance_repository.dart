import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import 'attendance_queue.dart';

class AttendanceRepository {
  AttendanceRepository(this._client, this._sessionStore, this._queue);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final AttendanceQueue _queue;

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

  Future<void> check(String type) async {
    final session = await _requireSession();
    try {
      final response = await _client.post(
        session.baseUrl,
        HrApiEndpoints.checkIn,
        data: {'type': type},
      );
      final envelope = ApiEnvelope<Object?>.fromJson(response, (value) => value);
      if (!envelope.ok) throw Exception(envelope.message);
    } catch (_) {
      await _queue.enqueue(
        PendingAttendanceOp(type: type, createdAt: DateTime.now()),
      );
    }
  }

  Future<List<PendingAttendanceOp>> pending() => _queue.read();

  Future<HrSession> _requireSession() async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    return session;
  }
}

class AttendanceStatus {
  final bool checkedIn;
  final String? lastCheckIn;
  final String? lastCheckOut;

  const AttendanceStatus({
    required this.checkedIn,
    this.lastCheckIn,
    this.lastCheckOut,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      checkedIn: json['checked_in'] == true,
      lastCheckIn: json['last_check_in'] as String?,
      lastCheckOut: json['last_check_out'] as String?,
    );
  }
}
