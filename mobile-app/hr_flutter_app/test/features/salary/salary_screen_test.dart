import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/read_cache.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/salary/data/salary_repository.dart';
import 'package:bude_hr/features/salary/presentation/salary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders salary slip list', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          salaryRepositoryProvider.overrideWithValue(
            _FakeSalaryRepository(store),
          ),
        ],
        child: const MaterialApp(home: SalaryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('2026-01-01 to 2026-01-31'), findsOneWidget);
    expect(find.text('100000'), findsOneWidget);
  });

  testWidgets('shows permission denied state', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          salaryRepositoryProvider.overrideWithValue(
            _FailingSalaryRepository(store),
          ),
        ],
        child: const MaterialApp(home: SalaryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load salary slips.'), findsOneWidget);
  });

  testWidgets('shows empty state when no slips exist', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          salaryRepositoryProvider.overrideWithValue(
            _EmptySalaryRepository(store),
          ),
        ],
        child: const MaterialApp(home: SalaryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No salary slips available.'), findsOneWidget);
  });
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _FakeSalaryRepository extends SalaryRepository {
  _FakeSalaryRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<SalarySlipSummary>>> list() async => Cached(
        const [
          SalarySlipSummary(
            name: 'SAL-2026-01',
            startDate: '2026-01-01',
            endDate: '2026-01-31',
            netPay: 100000,
          ),
        ],
        DateTime.now(),
      );
}

class _FailingSalaryRepository extends SalaryRepository {
  _FailingSalaryRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<SalarySlipSummary>>> list() =>
      throw Exception('Permission denied');
}

class _EmptySalaryRepository extends SalaryRepository {
  _EmptySalaryRepository(SecureSessionStore store)
      : super(HrApiClient(store), store);

  @override
  Future<Cached<List<SalarySlipSummary>>> list() async =>
      Cached(const [], DateTime.now());
}
