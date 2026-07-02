import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class ManagerRepository {
  ManagerRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<ManagerSummary> summary() async {
    final session = await _sessionStore.read();
    if (session == null) return const ManagerSummary(pendingLeaves: 0, pendingExpenses: 0);
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.managerSummary);
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    return ManagerSummary.fromJson(envelope.data ?? const {});
  }

  Future<List<PendingLeaveApproval>> pendingLeaves() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.managerPendingLeaves);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) =>
            PendingLeaveApproval.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<DirectReport>> directReports() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.managerDirectReports);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) =>
            DirectReport.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<PendingExpenseApproval>> pendingExpenses() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.managerPendingExpenses,
    );
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) => PendingExpenseApproval.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> decideLeave(
    String name, {
    required bool approved,
    String? comment,
  }) =>
      _decide(HrApiEndpoints.decideLeave, name, approved, comment);

  Future<void> decideExpense(
    String name, {
    required bool approved,
    String? comment,
  }) =>
      _decide(HrApiEndpoints.decideExpense, name, approved, comment);

  Future<void> _decide(
    String path,
    String name,
    bool approved,
    String? comment,
  ) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.post(
      session.baseUrl,
      path,
      data: {'name': name, 'approved': approved, 'comment': comment},
    );
    final envelope = ApiEnvelope<Object?>.fromJson(response, (value) => value);
    if (!envelope.ok) {
      throw Exception(envelope.message ?? 'Unable to record decision.');
    }
  }
}

class ManagerSummary {
  final int pendingLeaves;
  final int pendingExpenses;

  const ManagerSummary({
    required this.pendingLeaves,
    required this.pendingExpenses,
  });

  factory ManagerSummary.fromJson(Map<String, dynamic> json) {
    return ManagerSummary(
      pendingLeaves: (json['pending_leaves'] as num? ?? 0).toInt(),
      pendingExpenses: (json['pending_expenses'] as num? ?? 0).toInt(),
    );
  }
}

class DirectReport {
  final String employee;
  final String employeeName;
  final String department;
  final String designation;
  final String companyEmail;
  final String cellNumber;

  const DirectReport({
    required this.employee,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.companyEmail,
    required this.cellNumber,
  });

  factory DirectReport.fromJson(Map<String, dynamic> json) {
    return DirectReport(
      employee: json['employee'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      companyEmail: json['company_email'] as String? ?? '',
      cellNumber: json['cell_number'] as String? ?? '',
    );
  }
}

class PendingLeaveApproval {
  final String name;
  final String employeeName;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final num totalLeaveDays;

  const PendingLeaveApproval({
    required this.name,
    required this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
  });

  factory PendingLeaveApproval.fromJson(Map<String, dynamic> json) {
    return PendingLeaveApproval(
      name: json['name'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? '',
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      totalLeaveDays: json['total_leave_days'] as num? ?? 0,
    );
  }
}

class PendingExpenseApproval {
  final String name;
  final String employeeName;
  final num totalClaimedAmount;
  final String postingDate;

  const PendingExpenseApproval({
    required this.name,
    required this.employeeName,
    required this.totalClaimedAmount,
    required this.postingDate,
  });

  factory PendingExpenseApproval.fromJson(Map<String, dynamic> json) {
    return PendingExpenseApproval(
      name: json['name'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      totalClaimedAmount: json['total_claimed_amount'] as num? ?? 0,
      postingDate: json['posting_date'] as String? ?? '',
    );
  }
}
