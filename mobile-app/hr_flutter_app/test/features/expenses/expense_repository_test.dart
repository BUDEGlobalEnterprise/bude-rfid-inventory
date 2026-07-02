import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/pending_operation.dart';
import 'package:bude_hr/core/offline/pending_operations_queue.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/expenses/data/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const session = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'employee@example.com',
    fullName: 'Test Employee',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: ['Employee'],
  );

  test('parses expense claim summary payload', () {
    final claim = ExpenseClaimSummary.fromJson({
      'name': 'EXP-001',
      'status': 'Draft',
      'total_claimed_amount': 125,
    });

    expect(claim.name, 'EXP-001');
    expect(claim.totalClaimedAmount, 125);
  });

  test('queues an expense draft offline when submit fails', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    final repository = ExpenseRepository(
      _RespondingApiClient(ok: false),
      _FixedSessionStore(session),
      queue,
    );

    await repository.submit(
      type: 'Travel',
      amount: 50,
      postingDate: '2026-07-02',
    );

    final drafts = await repository.pendingDrafts();
    expect(drafts, hasLength(1));
    expect(drafts.single.payload['expense_type'], 'Travel');
    expect(drafts.single.payload['posting_date'], '2026-07-02');
  });

  test('retryDrafts clears a draft once it syncs', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(
      PendingHrOperation(
        id: 'd-1',
        type: PendingOperationType.expenseDraft,
        payload: const {'expense_type': 'Travel', 'amount': 50},
        createdAt: DateTime.parse('2026-07-01T09:00:00'),
      ),
    );
    final repository = ExpenseRepository(
      _RespondingApiClient(ok: true),
      _FixedSessionStore(session),
      queue,
    );

    final error = await repository.retryDrafts();

    expect(error, isNull);
    expect(await repository.pendingDrafts(), isEmpty);
  });

  test('uploadAttachment returns the stored file url', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ExpenseRepository(
      _RespondingApiClient(
        ok: true,
        responseData: {'file_url': '/private/files/receipt.jpg'},
      ),
      _FixedSessionStore(session),
      PendingOperationsQueue(),
    );

    final url = await repository.uploadAttachment(
      claimName: 'EXP-001',
      fileName: 'receipt.jpg',
      contentBase64: 'aGVsbG8=',
    );

    expect(url, '/private/files/receipt.jpg');
  });

  test('uploadAttachment throws when the backend rejects it', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ExpenseRepository(
      _RespondingApiClient(ok: false),
      _FixedSessionStore(session),
      PendingOperationsQueue(),
    );

    expect(
      repository.uploadAttachment(
        claimName: 'EXP-001',
        fileName: 'receipt.jpg',
        contentBase64: 'aGVsbG8=',
      ),
      throwsException,
    );
  });
}

class _FixedSessionStore extends SecureSessionStore {
  _FixedSessionStore(this._session);

  final HrSession _session;

  @override
  Future<HrSession?> read() async => _session;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _RespondingApiClient extends HrApiClient {
  _RespondingApiClient({required this.ok, this.responseData})
      : super(_FixedSessionStore(_dummySession));

  final bool ok;
  final Map<String, dynamic>? responseData;

  static const _dummySession = HrSession(
    baseUrl: 'https://erp.example.com',
    user: 'employee@example.com',
    fullName: 'Test Employee',
    apiKey: 'key',
    apiSecret: 'secret',
    roles: ['Employee'],
  );

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return ok
        ? {'ok': true, if (responseData != null) 'data': responseData}
        : {'ok': false, 'message': 'Server error.'};
  }
}
