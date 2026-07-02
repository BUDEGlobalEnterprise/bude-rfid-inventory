import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/read_cache.dart';
import '../../../core/storage/secure_session_store.dart';

class LeaveRepository {
  LeaveRepository(this._client, this._sessionStore, [ReadCache? cache])
      : _cache = cache ?? ReadCache();

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final ReadCache _cache;

  Future<Cached<List<LeaveBalance>>> balances() async {
    final session = await _sessionStore.read();
    if (session == null) return Cached(const [], DateTime.now());
    return cacheThrough(
      cache: _cache,
      key: 'leave_balances',
      fetchRaw: () async {
        final response =
            await _client.get(session.baseUrl, HrApiEndpoints.leaveBalances);
        final envelope = ApiEnvelope<List<dynamic>>.fromJson(
          response,
          (value) => List<dynamic>.from(value as List? ?? const []),
        );
        return envelope.data ?? const [];
      },
      parse: (raw) => (raw as List)
          .map((row) =>
              LeaveBalance.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }

  Future<void> apply({
    required String leaveType,
    required String fromDate,
    required String toDate,
    String? reason,
    bool halfDay = false,
    String? halfDayDate,
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
        'half_day': halfDay,
        'half_day_date': halfDay ? halfDayDate ?? fromDate : null,
      },
    );
  }

  Future<List<LeaveApplication>> requests() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.leaveRequests);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) =>
            LeaveApplication.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<LeaveApplication> detail(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.leaveRequestDetail,
      query: {'name': name},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok || envelope.data == null) {
      throw Exception(envelope.message ?? 'Unable to load leave application.');
    }
    return LeaveApplication.fromJson(envelope.data!);
  }

  Future<void> cancel(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.post(
      session.baseUrl,
      HrApiEndpoints.cancelLeave,
      data: {'name': name},
    );
    final envelope = ApiEnvelope<Object?>.fromJson(response, (value) => value);
    if (!envelope.ok) {
      throw Exception(envelope.message ?? 'Unable to cancel leave.');
    }
  }
}

class LeaveApplication {
  final String name;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final String status;
  final num totalLeaveDays;
  final String description;
  final bool cancellable;

  const LeaveApplication({
    required this.name,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.totalLeaveDays,
    required this.description,
    required this.cancellable,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      name: json['name'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? '',
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalLeaveDays: json['total_leave_days'] as num? ?? 0,
      description: json['description'] as String? ?? '',
      cancellable: json['cancellable'] == true,
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
