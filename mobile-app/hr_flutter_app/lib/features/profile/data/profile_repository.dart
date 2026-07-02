import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/read_cache.dart';
import '../../../core/storage/secure_session_store.dart';

class ProfileRepository {
  ProfileRepository(this._client, this._sessionStore, [ReadCache? cache])
      : _cache = cache ?? ReadCache();

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final ReadCache _cache;

  Future<Cached<EmployeeProfile?>> get() async {
    final session = await _sessionStore.read();
    if (session == null) return Cached(null, DateTime.now());
    return cacheThrough(
      cache: _cache,
      key: 'profile',
      fetchRaw: () async {
        final response =
            await _client.get(session.baseUrl, HrApiEndpoints.profile);
        final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
          response,
          (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
        );
        return envelope.data ?? const {};
      },
      parse: (raw) {
        final map = raw as Map;
        return map.isEmpty
            ? null
            : EmployeeProfile.fromJson(Map<String, dynamic>.from(map));
      },
    );
  }

  Future<List<EmployeeDocument>> documents() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.employeeDocuments);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map(
          (row) => EmployeeDocument.fromJson(
            Map<String, dynamic>.from(row as Map),
            baseUrl: session.baseUrl,
          ),
        )
        .toList();
  }
}

class EmployeeProfile {
  final String employee;
  final String employeeName;
  final String company;
  final String department;
  final String designation;
  final String dateOfJoining;
  final String reportsTo;
  final String cellNumber;
  final String personalEmail;
  final String companyEmail;
  final String emergencyPhoneNumber;
  final String emergencyContact;
  final String emergencyRelation;

  const EmployeeProfile({
    required this.employee,
    required this.employeeName,
    required this.company,
    required this.department,
    required this.designation,
    required this.dateOfJoining,
    required this.reportsTo,
    required this.cellNumber,
    required this.personalEmail,
    required this.companyEmail,
    required this.emergencyPhoneNumber,
    required this.emergencyContact,
    required this.emergencyRelation,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      employee: json['employee'] as String? ?? json['name'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      dateOfJoining: json['date_of_joining'] as String? ?? '',
      reportsTo: json['reports_to'] as String? ?? '',
      cellNumber: json['cell_number'] as String? ?? '',
      personalEmail: json['personal_email'] as String? ?? '',
      companyEmail: json['company_email'] as String? ?? '',
      emergencyPhoneNumber: json['emergency_phone_number'] as String? ?? '',
      emergencyContact: json['person_to_be_contacted'] as String? ?? '',
      emergencyRelation: json['relation'] as String? ?? '',
    );
  }
}

class EmployeeDocument {
  final String name;
  final String fileName;
  final String fileUrl;
  final bool isPrivate;

  const EmployeeDocument({
    required this.name,
    required this.fileName,
    required this.fileUrl,
    required this.isPrivate,
  });

  factory EmployeeDocument.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final rawUrl = json['file_url'] as String? ?? '';
    return EmployeeDocument(
      name: json['name'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileUrl: _absoluteUrl(baseUrl, rawUrl),
      isPrivate: json['is_private'] == true || json['is_private'] == 1,
    );
  }

  static String _absoluteUrl(String baseUrl, String rawUrl) {
    if (rawUrl.isEmpty ||
        rawUrl.startsWith('http://') ||
        rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    return '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/'
        '${rawUrl.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
