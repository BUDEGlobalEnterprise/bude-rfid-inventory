import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/receipt/data/receipt_op_submitter.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_draft.dart';
import 'package:bude_inventory/features/receipt/presentation/providers/receipt_providers.dart'
    as receipt;
import 'package:bude_inventory/features/receipt/presentation/receipt_screen.dart';
import 'package:bude_inventory/features/scan_session/domain/scanned_item.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
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
    'scan-session results merge duplicates and queue one stock receipt payload',
    (tester) async {
      final queue = SyncQueue(box: FakeBox());
      final network = _offlineNetwork();
      final notifier = receipt.ReceiptDraftNotifier();

      await tester.pumpWidget(
        _ReceiptHost(
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

      expect(find.textContaining('No items yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Queue receipt'), findsNothing);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Start scan session'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use scanned goods'));
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
      expect(notifier.state.isSubmittable, isFalse);

      notifier
        ..setTarget('Receiving - A')
        ..setTargetLocation('Dock 1 - A')
        ..setAgainstPo('PO-2026-0001')
        ..updateAllocations(
          'ITEM-B',
          const [
            TrackingAllocation(
              batchNo: 'BATCH-001',
              expiryDate: '2030-12-31',
              qty: 1,
            ),
          ],
        );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.pump();
      expect(
        notifier.state.lines
            .singleWhere((line) => line.itemCode == 'ITEM-A')
            .qty,
        4,
      );

      expect(notifier.state.isSubmittable, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Queue receipt'));
      await tester.pump();

      final ops = queue.all();
      expect(ops, hasLength(1));
      final op = ops.single;
      expect(op.type, kStockReceiptOpType);
      expect(op.status, OpStatus.pending);
      expect(op.payload, {
        'target_warehouse': 'Receiving - A',
        'target_location': 'Dock 1 - A',
        'against_po': 'PO-2026-0001',
        'items': [
          {'item_code': 'ITEM-A', 'qty': 4.0},
          {
            'item_code': 'ITEM-B',
            'qty': 1.0,
            'allocations': [
              {
                'qty': 1.0,
                'batch_no': 'BATCH-001',
                'expiry_date': '2030-12-31',
              },
            ],
          },
        ],
        'company': 'Bude Global',
      });
      expect(find.textContaining('Receipt queued (op '), findsOneWidget);

      await queue.dispose();
    },
  );

  testWidgets('warehouse, PO failure, and empty-lines states remain visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ReceiptHost(
        queue: SyncQueue(box: FakeBox()),
        network: _offlineNetwork(),
        notifier: receipt.ReceiptDraftNotifier(),
        scanResult: const [],
        warehousesOverride: receipt.warehousesProvider.overrideWith(
          (ref) async => throw Exception('warehouse offline'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Failed to load warehouses: Exception: warehouse offline'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _ReceiptHost(
        queue: SyncQueue(box: FakeBox()),
        network: _offlineNetwork(),
        notifier: receipt.ReceiptDraftNotifier(),
        scanResult: const [],
        purchaseOrdersOverride: receipt.purchaseOrdersProvider.overrideWith(
          (ref) async => throw Exception('PO offline'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No items yet'), findsOneWidget);
    expect(find.text('Start a scan session as goods arrive.'), findsWidgets);
    expect(
      find.text('Could not load POs: Exception: PO offline'),
      findsOneWidget,
    );
  });
}

class _ReceiptHost extends StatelessWidget {
  final SyncQueue queue;
  final NetworkInfoImpl network;
  final receipt.ReceiptDraftNotifier notifier;
  final List<ScannedItem> scanResult;
  final Override? warehousesOverride;
  final Override? purchaseOrdersOverride;

  const _ReceiptHost({
    required this.queue,
    required this.network,
    required this.notifier,
    required this.scanResult,
    this.warehousesOverride,
    this.purchaseOrdersOverride,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/receipt',
      routes: [
        GoRoute(
          path: '/receipt',
          builder: (context, state) => const ReceiptScreen(),
        ),
        GoRoute(
          path: '/scan-session',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop(scanResult),
                child: const Text('Use scanned goods'),
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
        receipt.receiptDraftProvider.overrideWith((ref) => notifier),
        warehousesOverride ??
            receipt.warehousesProvider.overrideWith(
              (ref) async => ['Receiving - A'],
            ),
        receipt.warehouseLocationsProvider.overrideWith(
          (ref, warehouse) async => switch (warehouse) {
            'Receiving - A' => ['Dock 1 - A'],
            _ => const <String>[],
          },
        ),
        purchaseOrdersOverride ??
            receipt.purchaseOrdersProvider.overrideWith(
              (ref) async => ['PO-2026-0001'],
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

_MockNetworkInfo _offlineNetwork() {
  final network = _MockNetworkInfo();
  when(() => network.isConnected).thenAnswer((_) async => false);
  when(() => network.onConnectivityChanged())
      .thenAnswer((_) => const Stream<bool>.empty());
  return network;
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
