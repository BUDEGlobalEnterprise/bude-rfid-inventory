import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class ProfileRepository {
  ProfileRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<EmployeeProfile?> get() async {
    final session = await _sessionStore.read();
    if (session == null) return null;
    final response = await _client.get(session.baseUrl, HrApiEndpoints.profile);
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map),
    );
    return envelope.data == null ? null : EmployeeProfile.fromJson(envelope.data!);
  }
}

class EmployeeProfile {
  final String employee;
  final String employeeName;
  final String company;
  final String department;
  final String designation;

  const EmployeeProfile({
    required this.employee,
    required this.employeeName,
    required this.company,
    required this.department,
    required this.designation,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      employee: json['employee'] as String? ?? json['name'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
    );
  }
}
