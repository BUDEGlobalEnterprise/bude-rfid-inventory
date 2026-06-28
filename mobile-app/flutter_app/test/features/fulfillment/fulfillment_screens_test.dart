import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/features/fulfillment/domain/sales_order.dart';
import 'package:bude_inventory/features/fulfillment/presentation/providers/fulfillment_providers.dart';
import 'package:bude_inventory/features/fulfillment/presentation/sales_order_fulfillment_screen.dart';
import 'package:bude_inventory/features/fulfillment/presentation/sales_order_list_screen.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_box.dart';

void main() {
  testWidgets('Sales Order list shows empty state', (tester) async {
    await tester.pumpWidget(
      _Host(
        overrides: [
          salesOrderListProvider.overrideWith((ref) async => const []),
        ],
        child: const SalesOrderListScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('No Sales Orders to fulfill'), findsOneWidget);
  });

  testWidgets('Sales Order list shows open orders', (tester) async {
    await tester.pumpWidget(
      _Host(
        overrides: [
          salesOrderListProvider.overrideWith(
            (ref) async => const [
              SalesOrderSummary(
                name: 'SO-001',
                customer: 'Acme',
                itemCount: 2,
                pendingQty: 3,
              ),
            ],
          ),
        ],
        child: const SalesOrderListScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('SO-001'), findsOneWidget);
    expect(find.textContaining('Acme'), findsOneWidget);
  });

  testWidgets('Fulfillment screen shows pick pack dispatch stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        overrides: [
          fulfillmentDraftBoxProvider.overrideWithValue(FakeBox()),
          salesOrderDetailProvider.overrideWith(
            (ref, order) async => const SalesOrderDetail(
              name: 'SO-001',
              customer: 'Acme',
              items: [
                SalesOrderLine(
                  salesOrderItem: 'SOI-1',
                  itemCode: 'ITEM-1',
                  itemName: 'Item 1',
                  pendingQty: 2,
                ),
              ],
            ),
          ),
          warehousesProvider.overrideWith((ref) async => ['Stores - A']),
          warehouseLocationsProvider.overrideWith(
            (ref, warehouse) async => const <String>[],
          ),
        ],
        child: const SalesOrderFulfillmentScreen(salesOrder: 'SO-001'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pick'), findsWidgets);
    expect(find.text('Pack'), findsWidgets);
    expect(find.text('Dispatch'), findsWidgets);
    expect(find.text('ITEM-1'), findsOneWidget);

    await tester.tap(find.text('Pack').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Pick every line at the exact Sales Order quantity before packing.',
      ),
      findsOneWidget,
    );
  });
}

class _Host extends StatelessWidget {
  final List<Override> overrides;
  final Widget child;

  const _Host({
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
