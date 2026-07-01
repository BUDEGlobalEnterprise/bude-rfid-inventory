import 'dart:async';

import 'package:bude_inventory/core/ui/loading_shimmer.dart';
import 'package:bude_inventory/features/fulfillment/domain/fulfillment_route_extra.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_route_extra.dart';
import 'package:bude_inventory/features/tasks/domain/warehouse_task.dart';
import 'package:bude_inventory/features/tasks/presentation/providers/warehouse_task_providers.dart';
import 'package:bude_inventory/features/tasks/presentation/warehouse_task_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renders grouped task rows and filters assigned tasks', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(tasks: _tasks()));
    await tester.pump();

    expect(find.text('Warehouse tasks'), findsOneWidget);
    expect(find.text('High priority (1)'), findsOneWidget);
    expect(find.text('Medium priority (1)'), findsOneWidget);
    expect(find.text('Low priority (1)'), findsOneWidget);
    expect(find.text('Receive PO-001'), findsOneWidget);
    expect(find.text('Fulfill SO-001'), findsOneWidget);
    expect(find.text('Calibrate'), findsOneWidget);

    await tester.tap(find.text('Assigned to me'));
    await tester.pumpAndSettle();

    expect(find.text('Receive PO-001'), findsOneWidget);
    expect(find.text('Fulfill SO-001'), findsNothing);
    expect(find.text('Calibrate'), findsNothing);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(const _Host(tasks: []));
    await tester.pump();

    expect(find.text('No warehouse tasks'), findsOneWidget);
  });

  testWidgets('shows loading and error states', (tester) async {
    final completer = Completer<List<WarehouseTask>>();
    await tester.pumpWidget(_AsyncHost(future: completer.future));
    await tester.pump();

    expect(find.byType(ShimmerList), findsOneWidget);

    completer.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not load tasks'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('PO task opens receipt with PO and ToDo metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(
        tasks: [_tasks().first],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Receive PO-001'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt PO-001 TODO-PO'), findsOneWidget);
  });

  testWidgets('SO and asset tasks open their existing workflows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(
        tasks: [_tasks()[1], _tasks()[2]],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Fulfill SO-001'));
    await tester.pumpAndSettle();
    expect(find.text('Fulfillment SO-001 TODO-SO'), findsOneWidget);

    await tester.pumpWidget(
      _RouterHost(
        tasks: [_tasks()[2]],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Calibrate'));
    await tester.pumpAndSettle();
    expect(find.text('Asset AST-001 AML-001 TODO-AML'), findsOneWidget);
  });
}

List<WarehouseTask> _tasks() => const [
      WarehouseTask(
        id: 'TODO-PO',
        kind: WarehouseTaskKind.receivePurchaseOrder,
        title: 'Receive PO-001',
        subtitle: 'Acme Supplies',
        priority: 'High',
        dueDate: '2026-07-02',
        assignedTo: 'receiver@example.com',
        company: 'Company A',
        sourceDoctype: 'Purchase Order',
        sourceName: 'PO-001',
        todoName: 'TODO-PO',
        itemCount: 2,
        pendingQty: 4,
      ),
      WarehouseTask(
        id: 'SO-001',
        kind: WarehouseTaskKind.fulfillSalesOrder,
        title: 'Fulfill SO-001',
        subtitle: 'Acme Customer',
        priority: 'Medium',
        dueDate: '2026-07-03',
        company: 'Company A',
        sourceDoctype: 'Sales Order',
        sourceName: 'SO-001',
        todoName: 'TODO-SO',
        itemCount: 1,
        pendingQty: 3,
      ),
      WarehouseTask(
        id: 'AML-001',
        kind: WarehouseTaskKind.assetMaintenance,
        title: 'Calibrate',
        subtitle: 'AST-001',
        priority: 'Low',
        dueDate: '2026-07-04',
        sourceDoctype: 'Asset Maintenance Log',
        sourceName: 'AML-001',
        todoName: 'TODO-AML',
        itemCount: 1,
        assetName: 'AST-001',
      ),
    ];

class _Host extends StatelessWidget {
  final List<WarehouseTask> tasks;

  const _Host({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        warehouseTasksProvider.overrideWith((ref) async => tasks),
        currentUsernameProvider.overrideWith(
          (ref) => 'receiver@example.com',
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WarehouseTaskScreen(),
      ),
    );
  }
}

class _RouterHost extends StatelessWidget {
  final List<WarehouseTask> tasks;

  const _RouterHost({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/tasks',
      routes: [
        GoRoute(
          path: '/tasks',
          builder: (context, state) => const WarehouseTaskScreen(),
        ),
        GoRoute(
          path: '/receipt',
          builder: (context, state) {
            final extra = state.extra as ReceiptRouteExtra?;
            return Scaffold(
              body: Text('Receipt ${extra?.againstPo} ${extra?.todoName}'),
            );
          },
        ),
        GoRoute(
          path: '/fulfillment/:salesOrder',
          builder: (context, state) {
            final extra = state.extra as FulfillmentRouteExtra?;
            return Scaffold(
              body: Text(
                'Fulfillment ${state.pathParameters['salesOrder']} '
                '${extra?.todoName}',
              ),
            );
          },
        ),
        GoRoute(
          path: '/assets/:name',
          builder: (context, state) => Scaffold(
            body: Text(
              'Asset ${state.pathParameters['name']} '
              '${state.uri.queryParameters['log']} '
              '${state.uri.queryParameters['todo']}',
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        warehouseTasksProvider.overrideWith((ref) async => tasks),
        currentUsernameProvider.overrideWith(
          (ref) => 'receiver@example.com',
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

class _AsyncHost extends StatelessWidget {
  final Future<List<WarehouseTask>> future;

  const _AsyncHost({required this.future});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        warehouseTasksProvider.overrideWith((ref) => future),
        currentUsernameProvider.overrideWith(
          (ref) => 'receiver@example.com',
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WarehouseTaskScreen(),
      ),
    );
  }
}
