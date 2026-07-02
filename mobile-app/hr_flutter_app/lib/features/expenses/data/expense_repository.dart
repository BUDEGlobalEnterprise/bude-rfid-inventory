import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/pending_operation.dart';
import '../../../core/offline/pending_operations_queue.dart';
import '../../../core/storage/secure_session_store.dart';

class ExpenseRepository {
  ExpenseRepository(this._client, this._sessionStore, this._queue);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final PendingOperationsQueue _queue;

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

  Future<List<String>> types() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response =
        await _client.get(session.baseUrl, HrApiEndpoints.expenseTypes);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const []).map((row) => row.toString()).toList();
  }

  Future<ExpenseClaimDetail> detail(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.expenseClaimDetail,
      query: {'name': name},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok || envelope.data == null) {
      throw Exception(envelope.message ?? 'Unable to load expense claim.');
    }
    return ExpenseClaimDetail.fromJson(envelope.data!);
  }

  /// Submits a claim online, falling back to the offline draft queue when the
  /// request fails so the entry is not lost.
  Future<void> submit({
    required String type,
    required num amount,
    String? description,
    String? postingDate,
  }) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    try {
      await _submitClaim(session, type, amount, description, postingDate);
    } catch (_) {
      final now = DateTime.now();
      await _queue.enqueue(
        PendingHrOperation(
          id: now.microsecondsSinceEpoch.toString(),
          type: PendingOperationType.expenseDraft,
          payload: {
            'expense_type': type,
            'amount': amount,
            'description': description,
            'posting_date': postingDate,
          },
          createdAt: now,
        ),
      );
    }
  }

  /// Uploads a base64-encoded receipt to an owned claim and returns the
  /// stored file URL. Callers convert picked files to base64.
  Future<String> uploadAttachment({
    required String claimName,
    required String fileName,
    required String contentBase64,
  }) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.post(
      session.baseUrl,
      HrApiEndpoints.uploadExpenseAttachment,
      data: {
        'claim_name': claimName,
        'file_name': fileName,
        'content_base64': contentBase64,
      },
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok) {
      throw Exception(envelope.message ?? 'Unable to upload attachment.');
    }
    return envelope.data?['file_url'] as String? ?? '';
  }

  Future<List<PendingHrOperation>> pendingDrafts() =>
      _queue.readByType(PendingOperationType.expenseDraft);

  /// Retries every queued draft; synced drafts are removed and the message
  /// from the last draft that still fails is returned, if any.
  Future<String?> retryDrafts() async {
    final session = await _sessionStore.read();
    if (session == null) return 'Not signed in.';
    String? lastError;
    for (final draft in await pendingDrafts()) {
      try {
        await _submitClaim(
          session,
          draft.payload['expense_type'] as String? ?? '',
          draft.payload['amount'] as num? ?? 0,
          draft.payload['description'] as String?,
          draft.payload['posting_date'] as String?,
        );
        await _queue.discard(draft.id);
      } catch (_) {
        lastError = 'Unable to sync a pending expense draft.';
      }
    }
    return lastError;
  }

  Future<void> discardDrafts() =>
      _queue.clearType(PendingOperationType.expenseDraft);

  Future<void> _submitClaim(
    HrSession session,
    String type,
    num amount,
    String? description,
    String? postingDate,
  ) async {
    final response = await _client.post(
      session.baseUrl,
      HrApiEndpoints.submitExpenseClaim,
      data: {
        'expense_type': type,
        'amount': amount,
        'description': description,
        'posting_date': postingDate,
      },
    );
    final envelope = ApiEnvelope<Object?>.fromJson(response, (value) => value);
    if (!envelope.ok) throw Exception(envelope.message);
  }
}

class ExpenseClaimDetail {
  final String name;
  final String status;
  final String approvalStatus;
  final String postingDate;
  final num totalClaimedAmount;
  final num totalSanctionedAmount;
  final List<ExpenseLine> expenses;

  const ExpenseClaimDetail({
    required this.name,
    required this.status,
    required this.approvalStatus,
    required this.postingDate,
    required this.totalClaimedAmount,
    required this.totalSanctionedAmount,
    required this.expenses,
  });

  factory ExpenseClaimDetail.fromJson(Map<String, dynamic> json) {
    return ExpenseClaimDetail(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      approvalStatus: json['approval_status'] as String? ?? '',
      postingDate: json['posting_date'] as String? ?? '',
      totalClaimedAmount: json['total_claimed_amount'] as num? ?? 0,
      totalSanctionedAmount: json['total_sanctioned_amount'] as num? ?? 0,
      expenses: (json['expenses'] as List? ?? const [])
          .map((row) => ExpenseLine.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }
}

class ExpenseLine {
  final String expenseType;
  final num amount;
  final num sanctionedAmount;
  final String description;

  const ExpenseLine({
    required this.expenseType,
    required this.amount,
    required this.sanctionedAmount,
    required this.description,
  });

  factory ExpenseLine.fromJson(Map<String, dynamic> json) {
    return ExpenseLine(
      expenseType: json['expense_type'] as String? ?? '',
      amount: json['amount'] as num? ?? 0,
      sanctionedAmount: json['sanctioned_amount'] as num? ?? 0,
      description: json['description'] as String? ?? '',
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
