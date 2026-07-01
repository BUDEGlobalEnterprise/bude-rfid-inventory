import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class SalaryRepository {
  SalaryRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<List<SalarySlipSummary>> list() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response = await _client.get(session.baseUrl, HrApiEndpoints.salarySlips);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) => SalarySlipSummary.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
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
