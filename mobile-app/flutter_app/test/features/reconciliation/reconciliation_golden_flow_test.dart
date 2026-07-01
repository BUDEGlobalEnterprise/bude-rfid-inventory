import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/authentication/domain/auth_repository.dart';
import 'package:bude_inventory/features/authentication/domain/auth_session.dart';
import 'package:bude_inventory/features/authentication/presentation/providers/auth_notifier.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/reconciliation/data/reconciliation_op_submitter.dart';
import 'package:bude_inventory/features/reconciliation/domain/reconciliation_draft.dart';
import 'package:bude_inventory/features/reconciliation/presentation/providers/reconciliation_providers.dart'
    as reconciliation;
import 'package:bude_inventory/features/reconciliation/presentation/reconciliation_approval_screen.dart';
import 'package:bude_inventory/features/reconciliation/presentation/reconciliation_screen.dart';
import 'package:bude_inventory/features/scan_session/domain/scanned_item.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

const _itemA = Item(
  itemCode: 'ITEM-A',
  itemName: 'Widget A',
  stockUom: 'Nos',
);

const _itemB = Item(
  itemCode: 'ITEM-B',
  itemName: 'Widget B',
  stockUom: 'Nos',
  hasBatchNo: true,
);

void main() {
  testWidgets(
    'scan-session results merge duplicates and queue one reconciliation payload',
    (tester) async {
      final queue = SyncQueue(box: FakeBox());
      final notifier = reconciliation.ReconciliationDraftNotifier();

      await tester.pumpWidget(
        _ReconciliationHost(
          queue: queue,
          notifier: notifier,
          scanResult: const [
            ScannedItem(barcode: 'A-001', item: _itemA, qty: 1),
            ScannedItem(barcode: 'A-001', item: _itemA, qty: 2),
            ScannedItem(barcode: 'B-001', item: _itemB, qty: 1),
          ],
          expectedQtyOverrides: [
            reconciliation
                .expectedQtyProvider(
                  const reconciliation.BinKey('ITEM-A', 'Rack Count 1 - A'),
                )
                .overrideWith((ref) async => 2.0),
            reconciliation
                .expectedQtyProvider(
                  const reconciliation.BinKey('ITEM-B', 'Rack Count 1 - A'),
                )
                .overrideWith((ref) async => 0.0),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Pick a warehouse first.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Queue count'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Start scan session').first,
            )
            .onPressed,
        isNull,
      );

      notifier
        ..setWarehouse('Stores - A')
        ..setLocation('Rack Count 1 - A');
      await tester.pump();

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Start scan session').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use counted items'));
      await tester.pumpAndSettle();

      expect(notifier.state.lines, hasLength(2));
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .countedQty,
        3,
      );
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .expectedQty,
        2,
      );
      expect(find.text('Expected 2'), findsOneWidget);
      expect(find.text('Variance 1'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.pump();
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .countedQty,
        4,
      );

      notifier.updateAllocations(
        'ITEM-B',
        const [TrackingAllocation(batchNo: 'BATCH-001', qty: 1)],
      );
      await tester.pump();

      expect(notifier.state.isSubmittable, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Queue count'));
      await tester.pump();

      final ops = queue.all();
      expect(ops, hasLength(1));
      final op = ops.single;
      expect(op.type, kStockReconciliationOpType);
      expect(op.status, OpStatus.pending);
      expect(op.payload, {
        'warehouse': 'Stores - A',
        'location': 'Rack Count 1 - A',
        'counts': [
          {'item_code': 'ITEM-A', 'qty': 4.0},
          {
            'item_code': 'ITEM-B',
            'qty': 1.0,
            'allocations': [
              {'qty': 1.0, 'batch_no': 'BATCH-001'},
            ],
          },
        ],
        'company': 'Bude Global',
      });
      expect(find.textContaining('Count queued (op '), findsOneWidget);

      await queue.dispose();
    },
  );

  testWidgets('large variance queues approval and approval promotes operation', (
    tester,
  ) async {
    final queue = SyncQueue(box: FakeBox());
    final notifier = reconciliation.ReconciliationDraftNotifier()
      ..setWarehouse('Stores - A')
      ..addLine(
        const CountLine(
          itemCode: 'ITEM-A',
          itemName: 'Widget A',
          countedQty: 5,
          expectedQty: 0,
        ),
      );

    await tester.pumpWidget(
      _ReconciliationHost(
        queue: queue,
        notifier: notifier,
        scanResult: const [],
        settings: const AppSettings(
          activeCompany: 'Bude Global',
          reconciliationVarianceThreshold: 1,
        ),
        authRepository: _ApprovingAuthRepository(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Queue count'));
    await tester.pumpAndSettle();

    final queued = queue.all().single;
    expect(queued.status, OpStatus.pendingApproval);
    expect(find.text('Supervisor Approval Required'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'manager@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Approve as Supervisor'));
    await tester.pumpAndSettle();

    final approved = queue.getById(queued.id)!;
    expect(approved.status, OpStatus.pending);
    expect(approved.payload['approved_by'], 'manager@example.com');

    await queue.dispose();
  });

  testWidgets('warehouse failure and empty-lines states remain visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ReconciliationHost(
        queue: SyncQueue(box: FakeBox()),
        notifier: reconciliation.ReconciliationDraftNotifier(),
        scanResult: const [],
        warehousesOverride: reconciliation.warehousesProvider.overrideWith(
          (ref) async => throw Exception('warehouse offline'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Failed to load warehouses: Exception: warehouse offline'),
      findsOneWidget,
    );

    final notifier = reconciliation.ReconciliationDraftNotifier()
      ..setWarehouse('Stores - A');
    await tester.pumpWidget(
      _ReconciliationHost(
        queue: SyncQueue(box: FakeBox()),
        notifier: notifier,
        scanResult: const [],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Scan items to start counting.'), findsOneWidget);
    expect(
      find.text('Start a scan session to build this count.'),
      findsWidgets,
    );
  });
}

class _ReconciliationHost extends StatelessWidget {
  final SyncQueue queue;
  final reconciliation.ReconciliationDraftNotifier notifier;
  final List<ScannedItem> scanResult;
  final AppSettings settings;
  final AuthRepository authRepository;
  final Override? warehousesOverride;
  final List<Override> expectedQtyOverrides;

  const _ReconciliationHost({
    required this.queue,
    required this.notifier,
    required this.scanResult,
    this.settings = const AppSettings(activeCompany: 'Bude Global'),
    this.authRepository = const _ApprovingAuthRepository(),
    this.warehousesOverride,
    this.expectedQtyOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/reconcile',
      routes: [
        GoRoute(
          path: '/reconcile',
          builder: (context, state) => const ReconciliationScreen(),
        ),
        GoRoute(
          path: '/scan-session',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop(scanResult),
                child: const Text('Use counted items'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/reconcile/approve',
          builder: (context, state) {
            final opId = state.extra! as String;
            return ReconciliationApprovalScreen(opId: opId);
          },
        ),
        GoRoute(
          path: '/sync',
          builder: (context, state) => const Scaffold(body: Text('Sync')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        syncQueueProvider.overrideWithValue(queue),
        networkInfoProvider.overrideWithValue(_offlineNetwork()),
        reconciliation.reconciliationDraftProvider.overrideWith(
          (ref) => notifier,
        ),
        warehousesOverride ??
            reconciliation.warehousesProvider.overrideWith(
              (ref) async => ['Stores - A'],
            ),
        reconciliation.warehouseLocationsProvider.overrideWith(
          (ref, warehouse) async => switch (warehouse) {
            'Stores - A' => ['Rack Count 1 - A'],
            _ => const <String>[],
          },
        ),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(settings),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        ...expectedQtyOverrides,
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

_MockNetworkInfo _offlineNetwork() {
  final network = _MockNetworkInfo();
  when(() => network.isConnected).thenAnswer((_) async => false);
  when(() => network.onConnectivityChanged())
      .thenAnswer((_) => const Stream<bool>.empty());
  return network;
}

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

class _ApprovingAuthRepository implements AuthRepository {
  const _ApprovingAuthRepository();

  @override
  Future<Either<Failure, (String, bool)>> validateSupervisor({
    required String username,
    required String password,
  }) async {
    return Right((username, true));
  }

  @override
  Future<Either<Failure, AuthSession?>> currentSession() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> expireSession() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> logout() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthSession?>> refreshSession() {
    throw UnimplementedError();
  }
}

class _SettingsNotifierForTest extends SettingsNotifier {
  _SettingsNotifierForTest(AppSettings settings)
      : super(_SettingsRepositoryForTest(settings)) {
    state = settings;
  }
}

class _SettingsRepositoryForTest implements SettingsRepository {
  AppSettings settings;

  _SettingsRepositoryForTest(this.settings);

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}
