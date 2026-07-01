import 'dart:async';

import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/router/app_router.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item_stock.dart';
import 'package:bude_inventory/features/inventory/domain/entities/stock_ledger_entry.dart';
import 'package:bude_inventory/features/inventory/domain/repositories/item_repository.dart';
import 'package:bude_inventory/features/inventory/presentation/item_detail_screen.dart';
import 'package:bude_inventory/features/inventory/presentation/providers/item_search_notifier.dart';
import 'package:bude_inventory/features/labels/presentation/label_screen.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_draft.dart';
import 'package:bude_inventory/features/receipt/presentation/providers/receipt_providers.dart'
    as receipt;
import 'package:bude_inventory/features/receipt/presentation/receipt_screen.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/sync/presentation/pending_queue_screen.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart'
    as transfer;
import 'package:bude_inventory/features/warehouse/domain/entities/warehouse_stock_line.dart';
import 'package:bude_inventory/features/warehouse/presentation/providers/warehouse_providers.dart'
    as warehouse;
import 'package:bude_inventory/features/warehouse/presentation/warehouse_detail_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

const _item = Item(
  itemCode: 'ITEM-001',
  itemName: 'Widget',
  stockUom: 'Nos',
  itemGroup: 'Finished Goods',
);

void main() {
  testWidgets('item detail print action opens labels with item data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AppHost(
        initialLocation: '/items/ITEM-001',
        overrides: [
          itemRepositoryProvider.overrideWithValue(_ItemRepositoryForTest()),
        ],
        routes: [
          GoRoute(
            path: '/items/:code',
            builder: (context, state) => ItemDetailScreen(
              itemCode: state.pathParameters['code']!,
            ),
          ),
          _labelRoute(),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Print label'));
    await tester.pumpAndSettle();

    expect(find.text('Label printing'), findsOneWidget);
    expect(find.text('ITEM-001'), findsWidgets);
    expect(find.text('Widget'), findsWidgets);
    expect(find.text('UOM: Nos'), findsOneWidget);
  });

  testWidgets('warehouse location print action opens labels with location data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AppHost(
        initialLocation: '/warehouse/Stores%20-%20A',
        overrides: [
          warehouse.warehouseStockProvider.overrideWith(
            (ref, warehouse) async => const <WarehouseStockLine>[],
          ),
          transfer.warehouseLocationsProvider.overrideWith(
            (ref, warehouse) async => const ['Dock 1 - A'],
          ),
        ],
        routes: [
          GoRoute(
            path: '/warehouse/:name',
            builder: (context, state) => WarehouseDetailScreen(
              warehouseName: Uri.decodeComponent(
                state.pathParameters['name']!,
              ),
            ),
          ),
          _labelRoute(),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Print location label'));
    await tester.pumpAndSettle();

    expect(find.text('Label printing'), findsOneWidget);
    expect(find.text('Dock 1 - A'), findsWidgets);
    expect(find.text('Warehouse: Stores - A'), findsOneWidget);
  });

  testWidgets('receipt queued snackbar print action opens receipt label', (
    tester,
  ) async {
    final queue = SyncQueue(box: FakeBox());
    final notifier = receipt.ReceiptDraftNotifier()
      ..setTarget('Receiving - A')
      ..setTargetLocation('Dock 1 - A')
      ..setAgainstPo('PO-0001')
      ..addLine(const ReceiptLine(itemCode: 'ITEM-001', qty: 2));

    await tester.pumpWidget(
      _ReceiptHost(queue: queue, notifier: notifier),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Queue receipt'));
    await tester.pump();
    await tester.tap(find.text('Print label'));
    await tester.pumpAndSettle();

    expect(find.text('Label printing'), findsOneWidget);
    expect(find.text('Goods receipt'), findsWidgets);
    expect(find.text('Target: Receiving - A'), findsOneWidget);
    expect(find.text('Location: Dock 1 - A'), findsOneWidget);
    expect(find.text('PO: PO-0001'), findsOneWidget);

    await queue.dispose();
  });

  testWidgets('pending queue receipt rows can open receipt labels', (
    tester,
  ) async {
    final queue = SyncQueue(box: FakeBox());
    final id = await queue.enqueue(
      type: 'stock_receipt',
      payload: const {
        'target_warehouse': 'Receiving - A',
        'target_location': 'Dock 1 - A',
        'against_po': 'PO-0001',
        'items': [
          {'item_code': 'ITEM-001', 'qty': 2},
        ],
        'company': 'Bude Global',
      },
    );

    await tester.pumpWidget(
      _AppHost(
        initialLocation: '/sync',
        overrides: [syncQueueProvider.overrideWithValue(queue)],
        routes: [
          GoRoute(
            path: '/sync',
            builder: (context, state) => const PendingQueueScreen(),
          ),
          _labelRoute(),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Goods receipt'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Print label'));
    await tester.pumpAndSettle();

    expect(find.text('Label printing'), findsOneWidget);
    expect(find.text(id), findsWidgets);
    expect(find.text('Target: Receiving - A'), findsOneWidget);
    expect(find.text('Company: Bude Global'), findsOneWidget);

    await queue.dispose();
  });
}

GoRoute _labelRoute() {
  return GoRoute(
    path: '/labels',
    builder: (context, state) => LabelScreen(
      initialRequest: labelRequestFromRouteExtra(state.extra),
    ),
  );
}

class _AppHost extends StatelessWidget {
  final String initialLocation;
  final List<Override> overrides;
  final List<RouteBase> routes;

  const _AppHost({
    required this.initialLocation,
    required this.overrides,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: routes,
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

class _ReceiptHost extends StatelessWidget {
  final SyncQueue queue;
  final receipt.ReceiptDraftNotifier notifier;

  const _ReceiptHost({required this.queue, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    return _AppHost(
      initialLocation: '/receipt',
      overrides: [
        syncQueueProvider.overrideWithValue(queue),
        networkInfoProvider.overrideWithValue(network),
        receipt.receiptDraftProvider.overrideWith((ref) => notifier),
        receipt.warehousesProvider.overrideWith(
          (ref) async => ['Receiving - A'],
        ),
        receipt.warehouseLocationsProvider.overrideWith(
          (ref, warehouse) async => const ['Dock 1 - A'],
        ),
        receipt.purchaseOrdersProvider.overrideWith(
          (ref) async => ['PO-0001'],
        ),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(
            const AppSettings(activeCompany: 'Bude Global'),
          ),
        ),
      ],
      routes: [
        GoRoute(
          path: '/receipt',
          builder: (context, state) => const ReceiptScreen(),
        ),
        _labelRoute(),
      ],
    );
  }
}

class _ItemRepositoryForTest implements ItemRepository {
  @override
  Future<Either<Failure, Item>> getByBarcode(String barcode) async {
    return const Right(_item);
  }

  @override
  Future<Either<Failure, List<StockLedgerEntry>>> getLedger(
    String itemCode, {
    String? warehouse,
    int limit = 50,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<ItemStock>>> getStock(
    String itemCode, {
    String? warehouse,
  }) async {
    return const Right([
      ItemStock(
        warehouse: 'Stores - A',
        actualQty: 5,
        reservedQty: 1,
        orderedQty: 0,
        projectedQty: 4,
        stockUom: 'Nos',
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<Item>>> search(
    String query, {
    int limit = 20,
    int page = 0,
    String? warehouse,
    String? itemGroup,
    bool inStock = false,
  }) async {
    return const Right([_item]);
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
