import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/scan_session/domain/scanned_item.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
import 'package:bude_inventory/features/transfer/data/transfer_op_submitter.dart';
import 'package:bude_inventory/features/transfer/domain/transfer_draft.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart'
    as transfer;
import 'package:bude_inventory/features/transfer/presentation/transfer_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
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
    'scan-session results merge duplicates and queue one stock transfer payload',
    (tester) async {
      final box = FakeBox();
      final queue = SyncQueue(box: box);
      final network = _MockNetworkInfo();
      final notifier = transfer.TransferDraftNotifier()
        ..setSource('Stores - A')
        ..setTarget('Stores - A');

      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => network.onConnectivityChanged())
          .thenAnswer((_) => const Stream<bool>.empty());

      await tester.pumpWidget(
        _TransferHost(
          queue: queue,
          network: network,
          notifier: notifier,
          scanResult: const [
            ScannedItem(barcode: 'A-001', item: _itemA, qty: 1),
            ScannedItem(barcode: 'A-001', item: _itemA, qty: 2),
            ScannedItem(barcode: 'B-001', item: _itemB, qty: 1),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Source and target must differ.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Queue transfer'),
        findsNothing,
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Start scan session'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use scanned items'));
      await tester.pumpAndSettle();

      expect(notifier.state.lines, hasLength(2));
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .qty,
        3,
      );
      expect(find.text('ITEM-A'), findsOneWidget);
      expect(find.text('ITEM-B'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.pump();
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .qty,
        4,
      );

      notifier
        ..setTarget('Floor - A')
        ..setSourceLocation('Rack 1 - A')
        ..setTargetLocation('Staging - A')
        ..updateAllocations(
          'ITEM-B',
          const [TrackingAllocation(batchNo: 'BATCH-001', qty: 1)],
        );
      await tester.pump();

      expect(notifier.state.isSubmittable, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Queue transfer'));
      await tester.pump();

      final ops = queue.all();
      expect(ops, hasLength(1));
      final op = ops.single;
      expect(op.type, kStockTransferOpType);
      expect(op.status, OpStatus.pending);
      expect(op.payload, {
        'source_warehouse': 'Stores - A',
        'target_warehouse': 'Floor - A',
        'source_location': 'Rack 1 - A',
        'target_location': 'Staging - A',
        'items': [
          {'item_code': 'ITEM-A', 'qty': 4.0},
          {
            'item_code': 'ITEM-B',
            'qty': 1.0,
            'allocations': [
              {'batch_no': 'BATCH-001', 'qty': 1.0},
            ],
          },
        ],
        'company': 'Bude Global',
      });
      expect(find.textContaining('Transfer queued (op '), findsOneWidget);

      await queue.dispose();
    },
  );

  testWidgets('warehouse failure and empty-lines states remain visible', (
    tester,
  ) async {
    final failureNetwork = _MockNetworkInfo();
    when(() => failureNetwork.isConnected).thenAnswer((_) async => false);
    when(() => failureNetwork.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    await tester.pumpWidget(
      _TransferHost(
        queue: SyncQueue(box: FakeBox()),
        network: failureNetwork,
        notifier: transfer.TransferDraftNotifier(),
        scanResult: const [],
        warehousesOverride: transfer.warehousesProvider.overrideWith(
          (ref) async => throw Exception('warehouse offline'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Failed to load warehouses: Exception: warehouse offline'),
      findsOneWidget,
    );

    final network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    await tester.pumpWidget(
      _TransferHost(
        queue: SyncQueue(box: FakeBox()),
        network: network,
        notifier: transfer.TransferDraftNotifier(),
        scanResult: const [],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No items yet'), findsOneWidget);
    expect(
      find.text('Start a scan session to add transfer lines.'),
      findsWidgets,
    );
  });
}

class _TransferHost extends StatelessWidget {
  final SyncQueue queue;
  final NetworkInfoImpl network;
  final transfer.TransferDraftNotifier notifier;
  final List<ScannedItem> scanResult;
  final Override? warehousesOverride;

  const _TransferHost({
    required this.queue,
    required this.network,
    required this.notifier,
    required this.scanResult,
    this.warehousesOverride,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/transfer',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferScreen(),
        ),
        GoRoute(
          path: '/scan-session',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop(scanResult),
                child: const Text('Use scanned items'),
              ),
            ),
          ),
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
        networkInfoProvider.overrideWithValue(network),
        transfer.transferDraftProvider.overrideWith((ref) => notifier),
        warehousesOverride ??
            transfer.warehousesProvider.overrideWith(
              (ref) async => ['Stores - A', 'Floor - A'],
            ),
        transfer.warehouseLocationsProvider.overrideWith(
          (ref, warehouse) async => switch (warehouse) {
            'Stores - A' => ['Rack 1 - A'],
            'Floor - A' => ['Staging - A'],
            _ => const <String>[],
          },
        ),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(
            const AppSettings(activeCompany: 'Bude Global'),
          ),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

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
