import 'dart:async';

import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/assets/data/asset_op_submitters.dart';
import 'package:bude_inventory/features/assets/data/asset_remote_data_source.dart';
import 'package:bude_inventory/features/assets/presentation/asset_detail_screen.dart';
import 'package:bude_inventory/features/assets/presentation/providers/asset_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

const _asset = AssetDetail(
  name: 'AST-001',
  assetName: 'Forklift 1',
  category: 'Vehicles',
  status: 'Submitted',
  location: 'Yard',
  custodianName: 'Jane Doe',
  purchaseDate: '2026-01-01',
  availableForUseDate: '2026-01-05',
  grossPurchaseAmount: 1000,
  valueAfterDepreciation: 800,
  epc: 'EPC-001',
);

void main() {
  testWidgets('shows a loading spinner then the info card', (tester) async {
    final completer = Completer<AssetDetail>();
    await tester.pumpWidget(_Host(assetFuture: completer.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_asset);
    await tester.pump();
    await tester.pump();

    expect(find.text('Forklift 1'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('EPC-001'), findsOneWidget);
    // No depreciation schedule on this asset → section omitted.
    expect(find.text('Depreciation'), findsNothing);
  });

  testWidgets('shows a load-failure message for an unknown asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(assetFuture: Future.error(Exception('not found'))),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Failed to load asset: Exception: not found'),
      findsOneWidget,
    );
  });

  testWidgets('renders the depreciation schedule when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        assetFuture: Future.value(
          _asset.copyWithSchedule([
            const DepreciationRow(
              scheduleDate: '2026-06-01',
              depreciationAmount: 10,
              accumulated: 10,
            ),
          ]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Depreciation'), findsOneWidget);
    expect(find.text('2026-06-01'), findsOneWidget);
  });

  testWidgets('Move and Report repair push the URI-encoded asset query param', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(assetFuture: Future.value(_asset), initialLocation: '/assets/AST-001'),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(find.text('Movement for AST-001'), findsOneWidget);
  });

  testWidgets('Report repair pushes with the asset query param', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(assetFuture: Future.value(_asset), initialLocation: '/assets/AST-001'),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Report repair'));
    await tester.pumpAndSettle();
    expect(find.text('Repair for AST-001'), findsOneWidget);
  });

  testWidgets('movement history: empty then populated', (tester) async {
    await tester.pumpWidget(
      _Host(assetFuture: Future.value(_asset), movements: const []),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No movement history'), findsOneWidget);

    await tester.pumpWidget(
      _Host(
        assetFuture: Future.value(_asset),
        movements: const [
          AssetMovementRow(
            parent: 'MOV-001',
            sourceLocation: 'Stores',
            targetLocation: 'Floor',
            transactionDate: '2026-06-01',
            purpose: 'Transfer',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Transfer'), findsOneWidget);
    expect(find.textContaining('Stores → Floor'), findsOneWidget);
  });

  testWidgets('maintenance section: empty state', (tester) async {
    await tester.pumpWidget(
      _Host(assetFuture: Future.value(_asset), maintenanceLogs: const []),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No scheduled maintenance'), findsOneWidget);
  });

  testWidgets(
    'tapping Complete enqueues a maintenance_log op without todo_name by default',
    (tester) async {
      final queue = SyncQueue(box: FakeBox());
      await tester.pumpWidget(
        _Host(
          assetFuture: Future.value(_asset),
          maintenanceLogs: const [
            MaintenanceLog(
              name: 'LOG-001',
              task: 'Inspect belts',
              dueDate: '2026-07-10',
            ),
          ],
          queue: queue,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Complete'));
      await tester.pump();

      final ops = queue.all();
      expect(ops, hasLength(1));
      expect(ops.single.type, kMaintenanceLogOpType);
      expect(ops.single.payload, {'log': 'LOG-001'});

      await queue.dispose();
    },
  );

  testWidgets(
    'tapping Complete includes todo_name when it matches the focused log',
    (tester) async {
      final queue = SyncQueue(box: FakeBox());
      await tester.pumpWidget(
        _Host(
          assetFuture: Future.value(_asset),
          maintenanceLogs: const [
            MaintenanceLog(
              name: 'LOG-001',
              task: 'Inspect belts',
              dueDate: '2026-07-10',
            ),
          ],
          queue: queue,
          focusMaintenanceLog: 'LOG-001',
          todoName: 'TODO-001',
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Complete'));
      await tester.pump();

      final ops = queue.all();
      expect(ops.single.payload, {'log': 'LOG-001', 'todo_name': 'TODO-001'});

      await queue.dispose();
    },
  );
}

extension on AssetDetail {
  AssetDetail copyWithSchedule(List<DepreciationRow> schedule) => AssetDetail(
        name: name,
        assetName: assetName,
        itemCode: itemCode,
        category: category,
        company: company,
        status: status,
        location: location,
        custodian: custodian,
        custodianName: custodianName,
        purchaseDate: purchaseDate,
        availableForUseDate: availableForUseDate,
        grossPurchaseAmount: grossPurchaseAmount,
        valueAfterDepreciation: valueAfterDepreciation,
        maintenanceRequired: maintenanceRequired,
        epc: epc,
        depreciationSchedule: schedule,
      );
}

class _Host extends StatelessWidget {
  final Future<AssetDetail> assetFuture;
  final List<AssetMovementRow> movements;
  final List<MaintenanceLog> maintenanceLogs;
  final SyncQueue? queue;
  final String? focusMaintenanceLog;
  final String? todoName;

  const _Host({
    required this.assetFuture,
    this.movements = const [],
    this.maintenanceLogs = const [],
    this.queue,
    this.focusMaintenanceLog,
    this.todoName,
  });

  @override
  Widget build(BuildContext context) {
    final network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    return ProviderScope(
      overrides: [
        assetDetailProvider.overrideWith((ref, name) => assetFuture),
        assetMovementsProvider.overrideWith((ref, name) async => movements),
        assetMaintenanceLogsProvider.overrideWith(
          (ref, name) async => maintenanceLogs,
        ),
        syncQueueProvider.overrideWithValue(
          queue ?? SyncQueue(box: FakeBox()),
        ),
        networkInfoProvider.overrideWithValue(network),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AssetDetailScreen(
          assetName: 'AST-001',
          focusMaintenanceLog: focusMaintenanceLog,
          todoName: todoName,
        ),
      ),
    );
  }
}

class _RouterHost extends StatelessWidget {
  final Future<AssetDetail> assetFuture;
  final String initialLocation;

  const _RouterHost({
    required this.assetFuture,
    required this.initialLocation,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/assets/:name',
          builder: (context, state) => AssetDetailScreen(
            assetName: state.pathParameters['name']!,
          ),
        ),
        GoRoute(
          path: '/asset-movement',
          builder: (context, state) => Scaffold(
            body: Text(
              'Movement for ${state.uri.queryParameters['asset']}',
            ),
          ),
        ),
        GoRoute(
          path: '/asset-repair',
          builder: (context, state) => Scaffold(
            body: Text(
              'Repair for ${state.uri.queryParameters['asset']}',
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        assetDetailProvider.overrideWith((ref, name) => assetFuture),
        assetMovementsProvider.overrideWith((ref, name) async => const []),
        assetMaintenanceLogsProvider.overrideWith(
          (ref, name) async => const [],
        ),
        syncQueueProvider.overrideWithValue(SyncQueue(box: FakeBox())),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
