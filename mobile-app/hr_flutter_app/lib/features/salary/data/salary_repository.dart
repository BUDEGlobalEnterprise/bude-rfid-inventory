import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/read_cache.dart';
import '../../../core/storage/secure_session_store.dart';

class SalaryRepository {
  SalaryRepository(this._client, this._sessionStore, [ReadCache? cache])
      : _cache = cache ?? ReadCache.secure();

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final ReadCache _cache;

  Future<Cached<List<SalarySlipSummary>>> list() async {
    final session = await _sessionStore.read();
    if (session == null) return Cached(const [], DateTime.now());
    // Only the slip list is cached; PDFs/detail are never persisted.
    return cacheThrough(
      cache: _cache,
      key: 'salary_slips',
      fetchRaw: () async {
        final response =
            await _client.get(session.baseUrl, HrApiEndpoints.salarySlips);
        final envelope = ApiEnvelope<List<dynamic>>.fromJson(
          response,
          (value) => List<dynamic>.from(value as List? ?? const []),
        );
        return envelope.data ?? const [];
      },
      parse: (raw) => (raw as List)
          .map((row) =>
              SalarySlipSummary.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }

  Future<SalarySlipDetail> detail(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.salarySlipDetail,
      query: {'name': name},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok || envelope.data == null) {
      throw SalaryAccessException(
        envelope.message ?? 'Unable to load salary slip.',
        code: envelope.code,
      );
    }
    return SalarySlipDetail.fromJson(envelope.data!);
  }

  Future<SalarySlipPdfLink> pdfLink(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.salarySlipPdfUrl,
      query: {'name': name},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok || envelope.data == null) {
      throw SalaryAccessException(
        envelope.message ?? 'Unable to prepare salary slip PDF.',
        code: envelope.code,
      );
    }
    return SalarySlipPdfLink.fromJson(envelope.data!);
  }
}

class SalaryAccessException implements Exception {
  SalaryAccessException(this.message, {this.code});
  final String message;
  final String? code;

  bool get isPermissionDenied =>
      code == 'PERMISSION_DENIED' || code == 'HR_SALARY_NOT_FOUND';
}

class SalarySlipDetail {
  final String name;
  final String startDate;
  final String endDate;
  final num grossPay;
  final num totalDeduction;
  final num netPay;
  final List<SalaryComponent> earnings;
  final List<SalaryComponent> deductions;

  const SalarySlipDetail({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.grossPay,
    required this.totalDeduction,
    required this.netPay,
    required this.earnings,
    required this.deductions,
  });

  factory SalarySlipDetail.fromJson(Map<String, dynamic> json) {
    List<SalaryComponent> parse(String key) =>
        (json[key] as List? ?? const [])
            .map((row) =>
                SalaryComponent.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
    return SalarySlipDetail(
      name: json['name'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      grossPay: json['gross_pay'] as num? ?? 0,
      totalDeduction: json['total_deduction'] as num? ?? 0,
      netPay: json['net_pay'] as num? ?? 0,
      earnings: parse('earnings'),
      deductions: parse('deductions'),
    );
  }
}

class SalarySlipPdfLink {
  final String name;
  final String url;

  const SalarySlipPdfLink({required this.name, required this.url});

  factory SalarySlipPdfLink.fromJson(Map<String, dynamic> json) {
    return SalarySlipPdfLink(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class SalaryComponent {
  final String component;
  final num amount;

  const SalaryComponent({required this.component, required this.amount});

  factory SalaryComponent.fromJson(Map<String, dynamic> json) {
    return SalaryComponent(
      component: json['component'] as String? ?? '',
      amount: json['amount'] as num? ?? 0,
    );
  }
}

class SalarySlipSummary {
  final String name;
  final String startDate;
  final String endDate;
  final num netPay;

  const SalarySlipSummary({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.netPay,
  });

  factory SalarySlipSummary.fromJson(Map<String, dynamic> json) {
    return SalarySlipSummary(
      name: json['name'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      netPay: json['net_pay'] as num? ?? 0,
    );
  }
}
