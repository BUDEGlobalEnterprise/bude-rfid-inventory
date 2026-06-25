import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/inventory/domain/repositories/item_repository.dart';
import 'package:bude_inventory/features/inventory/presentation/item_search_screen.dart';
import 'package:bude_inventory/features/inventory/presentation/providers/item_search_notifier.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_draft.dart';
import 'package:bude_inventory/features/receipt/presentation/providers/receipt_providers.dart'
    as receipt;
import 'package:bude_inventory/features/receipt/presentation/receipt_screen.dart';
import 'package:bude_inventory/features/reconciliation/presentation/providers/reconciliation_providers.dart'
    as reconciliation;
import 'package:bude_inventory/features/reconciliation/presentation/reconciliation_screen.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/transfer/domain/transfer_draft.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart'
    as transfer;
import 'package:bude_inventory/features/transfer/presentation/transfer_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item_stock.dart';
import 'package:bude_inventory/features/inventory/domain/entities/stock_ledger_entry.dart';
import 'package:bude_inventory/features/inventory/domain/usecases/search_items_usecase.dart';

const _seedItem = Item(
  itemCode: 'ITEM-001',
  itemName: 'Seeded Widget',
  stockUom: 'Nos',
);

void main() {
  testWidgets('transfer seeds an initial item once', (tester) async {
    final notifier = transfer.TransferDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          transfer.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A', 'Floor - A'],
          ),
          transfer.transferDraftProvider.overrideWith((ref) => notifier),
        ],
        child: const TransferScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ITEM-001'), findsOneWidget);
    expect(find.text('Seeded Widget'), findsOneWidget);
    expect(find.text('Added ITEM-001 to draft'), findsOneWidget);
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.qty, 1);
  });

  testWidgets('transfer does not duplicate an already drafted item', (
    tester,
  ) async {
    final notifier = transfer.TransferDraftNotifier()
      ..addLine(
        const TransferLine(
          itemCode: 'ITEM-001',
          itemName: 'Seeded Widget',
          qty: 3,
        ),
      );

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          transfer.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A', 'Floor - A'],
          ),
          transfer.transferDraftProvider.overrideWith((ref) => notifier),
        ],
        child: const TransferScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ITEM-001'), findsOneWidget);
    expect(find.text('ITEM-001 already in draft'), findsOneWidget);
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.qty, 3);
  });

  testWidgets('transfer applies saved source and target warehouses', (
    tester,
  ) async {
    final notifier = transfer.TransferDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          transfer.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A', 'Floor - A'],
          ),
          transfer.transferDraftProvider.overrideWith((ref) => notifier),
          settingsNotifierProvider.overrideWith(
            (ref) => _SettingsNotifierForTest(
              const AppSettings(
                defaultSourceWarehouse: 'Stores - A',
                defaultTargetWarehouse: 'Floor - A',
              ),
            ),
          ),
        ],
        child: const TransferScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(notifier.state.sourceWarehouse, 'Stores - A');
    expect(notifier.state.targetWarehouse, 'Floor - A');
  });

  testWidgets('transfer skips matching source and target defaults', (
    tester,
  ) async {
    final notifier = transfer.TransferDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          transfer.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A'],
          ),
          transfer.transferDraftProvider.overrideWith((ref) => notifier),
          settingsNotifierProvider.overrideWith(
            (ref) => _SettingsNotifierForTest(
              const AppSettings(
                defaultSourceWarehouse: 'Stores - A',
                defaultTargetWarehouse: 'Stores - A',
              ),
            ),
          ),
        ],
        child: const TransferScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(notifier.state.sourceWarehouse, 'Stores - A');
    expect(notifier.state.targetWarehouse, isNull);
  });

  testWidgets('receipt seeds an initial item once', (tester) async {
    final notifier = receipt.ReceiptDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          receipt.warehousesProvider.overrideWith(
            (ref) async => ['Receiving - A'],
          ),
          receipt.purchaseOrdersProvider.overrideWith((ref) async => []),
          receipt.receiptDraftProvider.overrideWith((ref) => notifier),
        ],
        child: const ReceiptScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ITEM-001'), findsOneWidget);
    expect(find.text('Seeded Widget'), findsOneWidget);
    expect(find.text('Added ITEM-001 to draft'), findsOneWidget);
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.qty, 1);
  });

  testWidgets('receipt does not duplicate an already drafted item', (
    tester,
  ) async {
    final notifier = receipt.ReceiptDraftNotifier()
      ..addLine(
        const ReceiptLine(
          itemCode: 'ITEM-001',
          itemName: 'Seeded Widget',
          qty: 4,
        ),
      );

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          receipt.warehousesProvider.overrideWith(
            (ref) async => ['Receiving - A'],
          ),
          receipt.purchaseOrdersProvider.overrideWith((ref) async => []),
          receipt.receiptDraftProvider.overrideWith((ref) => notifier),
        ],
        child: const ReceiptScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ITEM-001'), findsOneWidget);
    expect(find.text('ITEM-001 already in draft'), findsOneWidget);
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.qty, 4);
  });

  testWidgets('receipt applies saved target warehouse', (tester) async {
    final notifier = receipt.ReceiptDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          receipt.warehousesProvider.overrideWith(
            (ref) async => ['Receiving - A'],
          ),
          receipt.purchaseOrdersProvider.overrideWith((ref) async => []),
          receipt.receiptDraftProvider.overrideWith((ref) => notifier),
          settingsNotifierProvider.overrideWith(
            (ref) => _SettingsNotifierForTest(
              const AppSettings(defaultTargetWarehouse: 'Receiving - A'),
            ),
          ),
        ],
        child: const ReceiptScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(notifier.state.targetWarehouse, 'Receiving - A');
  });

  testWidgets('reconciliation waits for warehouse before seeding item', (
    tester,
  ) async {
    final notifier = reconciliation.ReconciliationDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          reconciliation.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A'],
          ),
          reconciliation.reconciliationDraftProvider.overrideWith(
            (ref) => notifier,
          ),
        ],
        child: const ReconciliationScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pick warehouse to count ITEM-001'), findsOneWidget);
    expect(notifier.state.lines, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stores - A').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('ITEM-001'), findsOneWidget);
    expect(find.text('Seeded Widget'), findsOneWidget);
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.countedQty, 1);
  });

  testWidgets('reconciliation applies default warehouse and seeds item', (
    tester,
  ) async {
    final notifier = reconciliation.ReconciliationDraftNotifier();

    await tester.pumpWidget(
      _LocalizedHost(
        overrides: [
          reconciliation.warehousesProvider.overrideWith(
            (ref) async => ['Stores - A'],
          ),
          reconciliation.reconciliationDraftProvider.overrideWith(
            (ref) => notifier,
          ),
          settingsNotifierProvider.overrideWith(
            (ref) => _SettingsNotifierForTest(
              const AppSettings(defaultSourceWarehouse: 'Stores - A'),
            ),
          ),
        ],
        child: const ReconciliationScreen(initialItem: _seedItem),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(notifier.state.warehouse, 'Stores - A');
    expect(notifier.state.lines, hasLength(1));
    expect(notifier.state.lines.single.itemCode, 'ITEM-001');
    expect(notifier.state.lines.single.countedQty, 1);
  });

  testWidgets('search result menu exposes operation shortcuts', (tester) async {
    await tester.pumpWidget(
      _SearchHost(
        notifier: _SearchNotifierForTest(
          const ItemSearchResults(
            items: [_seedItem],
            query: 'seed',
            filter: kEmptyFilter,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Item actions'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Count'), findsOneWidget);
  });
}

class _LocalizedHost extends StatelessWidget {
  final List<Override> overrides;
  final Widget child;

  const _LocalizedHost({
    required this.overrides,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

class _SearchHost extends StatelessWidget {
  final _SearchNotifierForTest notifier;

  const _SearchHost({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/items',
      routes: [
        GoRoute(
          path: '/items',
          builder: (context, state) => const ItemSearchScreen(),
        ),
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const Scaffold(body: Text('Transfer')),
        ),
        GoRoute(
          path: '/receipt',
          builder: (context, state) => const Scaffold(body: Text('Receipt')),
        ),
        GoRoute(
          path: '/reconcile',
          builder: (context, state) => const Scaffold(body: Text('Count')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        itemSearchNotifierProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

class _SearchNotifierForTest extends ItemSearchNotifier {
  _SearchNotifierForTest(ItemSearchState initial)
      : super(SearchItemsUseCase(_ItemRepositoryForTest())) {
    state = initial;
  }
}

class _ItemRepositoryForTest implements ItemRepository {
  @override
  Future<Either<Failure, Item>> getByBarcode(String barcode) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<StockLedgerEntry>>> getLedger(
    String itemCode, {
    int limit = 50,
    String? warehouse,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<ItemStock>>> getStock(
    String itemCode, {
    String? warehouse,
  }) async {
    return const Right([]);
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
    return const Right([_seedItem]);
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
