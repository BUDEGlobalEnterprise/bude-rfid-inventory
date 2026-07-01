import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class LeaveRepository {
  LeaveRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<List<LeaveBalance>> balances() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response = await _client.get(session.baseUrl, HrApiEndpoints.leaveBalances);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) => LeaveBalance.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> apply({
    required String leaveType,
    required String fromDate,
    required String toDate,
    String? reason,
  }) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    await _client.post(
      session.baseUrl,
      HrApiEndpoints.applyLeave,
      data: {
        'leave_type': leaveType,
        'from_date': fromDate,
        'to_date': toDate,
        'reason': reason,
      },
    );
  }
}

class LeaveBalance {
  final String leaveType;
  final num allocated;
  final num used;
  final num available;

  const LeaveBalance({
    required this.leaveType,
    required this.allocated,
    required this.used,
    required this.available,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveType: json['leave_type'] as String? ?? '',
      allocated: json['allocated'] as num? ?? 0,
      used: json['used'] as num? ?? 0,
      available: json['available'] as num? ?? 0,
    );
  }
}
