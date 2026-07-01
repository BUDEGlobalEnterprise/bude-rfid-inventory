import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class ExpenseRepository {
  ExpenseRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<List<ExpenseClaimSummary>> list() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response = await _client.get(session.baseUrl, HrApiEndpoints.expenseClaims);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) => ExpenseClaimSummary.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> submit({required String type, required num amount}) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    await _client.post(
      session.baseUrl,
      HrApiEndpoints.submitExpenseClaim,
      data: {'expense_type': type, 'amount': amount},
    );
  }
}

class ExpenseClaimSummary {
  final String name;
  final String status;
  final num totalClaimedAmount;

  const ExpenseClaimSummary({
    required this.name,
    required this.status,
    required this.totalClaimedAmount,
  });

  factory ExpenseClaimSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseClaimSummary(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalClaimedAmount: json['total_claimed_amount'] as num? ?? 0,
    );
  }
}
