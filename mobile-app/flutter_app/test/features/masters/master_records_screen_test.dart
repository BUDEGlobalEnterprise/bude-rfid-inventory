import 'dart:async';

import 'package:bude_inventory/core/ui/loading_shimmer.dart';
import 'package:bude_inventory/features/masters/data/masters_remote_data_source.dart';
import 'package:bude_inventory/features/masters/domain/master_def.dart';
import 'package:bude_inventory/features/masters/presentation/master_records_screen.dart';
import 'package:bude_inventory/features/masters/presentation/providers/masters_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _disableableDef = MasterDef(
  key: 'warehouse',
  label: 'Warehouses',
  doctype: 'Warehouse',
  canDisable: true,
  fields: [],
);

const _nonDisableableDef = MasterDef(
  key: 'item_group',
  label: 'Item Groups',
  doctype: 'Item Group',
  canDisable: false,
  fields: [],
);

class _FakeMastersDataSource extends MastersRemoteDataSource {
  final List<(String, String, bool)> setDisabledCalls = [];

  _FakeMastersDataSource() : super(Dio());

  @override
  Future<void> setDisabled(String master, String name, bool disabled) async {
    setDisabledCalls.add((master, name, disabled));
  }
}

void main() {
  testWidgets('shows loading then populated rows', (tester) async {
    final completer = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      _Host(
        def: _disableableDef,
        recordsOverride: masterRecordsProvider.overrideWith(
          (ref, args) => completer.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ShimmerList), findsOneWidget);

    completer.complete([
      {'name': 'Floor - A', 'warehouse_name': 'Floor'},
    ]);
    await tester.pump();
    await tester.pump();

    // _rowTitle skips 'name' and uses the first other string field.
    expect(find.text('Floor'), findsOneWidget);
    expect(find.text('Floor - A'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      _Host(
        def: _disableableDef,
        recordsOverride:
            masterRecordsProvider.overrideWith((ref, args) async => const []),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No records'), findsOneWidget);
  });

  testWidgets('shows a load-failure message', (tester) async {
    await tester.pumpWidget(
      _Host(
        def: _disableableDef,
        recordsOverride: masterRecordsProvider.overrideWith(
          (ref, args) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Failed to load: Exception: offline'),
      findsOneWidget,
    );
  });

  testWidgets('search submit re-queries with the trimmed term', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        def: _disableableDef,
        recordsOverride: masterRecordsProvider.overrideWith(
          (ref, args) async => args.search == 'floor'
              ? [
                  {'name': 'Floor - A', 'warehouse_name': 'Floor'},
                ]
              : const <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No records'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  floor  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(find.text('Floor'), findsOneWidget);
  });

  testWidgets('FAB navigates to the new-record route', (tester) async {
    await tester.pumpWidget(
      _RouterHost(
        def: _disableableDef,
        recordsOverride:
            masterRecordsProvider.overrideWith((ref, args) async => const []),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New'));
    await tester.pumpAndSettle();

    expect(find.text('Form: warehouse new'), findsOneWidget);
  });

  testWidgets('row tap navigates to the edit route (same path as the Edit menu item)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(
        def: _disableableDef,
        recordsOverride: masterRecordsProvider.overrideWith(
          (ref, args) async => [
            {'name': 'Floor A', 'warehouse_name': 'Floor'},
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Floor'));
    await tester.pumpAndSettle();

    expect(find.text('Form: warehouse edit Floor A'), findsOneWidget);
  });

  testWidgets('toggle menu item is hidden when the master cannot be disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        def: _nonDisableableDef,
        recordsOverride: masterRecordsProvider.overrideWith(
          (ref, args) async => [
            {'name': 'Products', 'item_group_name': 'Products'},
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Products').first,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Disable'), findsNothing);
    expect(find.text('Enable'), findsNothing);
  });

  testWidgets(
    'disabled detection covers disabled=1, enabled=0, and non-Active status; '
    'toggling calls setDisabled and refreshes',
    (tester) async {
      final fakeDataSource = _FakeMastersDataSource();
      await tester.pumpWidget(
        _Host(
          def: _disableableDef,
          dataSource: fakeDataSource,
          recordsOverride: masterRecordsProvider.overrideWith(
            (ref, args) async => [
              {'name': 'A', 'warehouse_name': 'A', 'disabled': 1},
              {'name': 'B', 'warehouse_name': 'B', 'enabled': 0},
              {'name': 'C', 'warehouse_name': 'C', 'status': 'Inactive'},
              {'name': 'D', 'warehouse_name': 'D', 'status': 'Active'},
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      Future<void> expectToggleLabel(String rowTitle, String label) async {
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, rowTitle).first,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        // Close the menu without selecting anything.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      await expectToggleLabel('A', 'Enable'); // disabled == 1
      await expectToggleLabel('B', 'Enable'); // enabled == 0
      await expectToggleLabel('C', 'Enable'); // status != Active
      await expectToggleLabel('D', 'Disable'); // status == Active

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'D').first,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();

      expect(fakeDataSource.setDisabledCalls, [('warehouse', 'D', true)]);
      expect(find.text('Disabled D'), findsOneWidget);
    },
  );
}

class _Host extends StatelessWidget {
  final MasterDef def;
  final Override recordsOverride;
  final MastersRemoteDataSource? dataSource;

  const _Host({
    required this.def,
    required this.recordsOverride,
    this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mastersCatalogProvider.overrideWith((ref) async => [def]),
        recordsOverride,
        if (dataSource != null)
          mastersDataSourceProvider.overrideWithValue(dataSource!),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MasterRecordsScreen(masterKey: def.key),
      ),
    );
  }
}

class _RouterHost extends StatelessWidget {
  final MasterDef def;
  final Override recordsOverride;

  const _RouterHost({required this.def, required this.recordsOverride});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/masters/${def.key}',
      routes: [
        GoRoute(
          path: '/masters/:key',
          builder: (context, state) =>
              MasterRecordsScreen(masterKey: state.pathParameters['key']!),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => Scaffold(
                body: Text('Form: ${state.pathParameters['key']} new'),
              ),
            ),
            GoRoute(
              path: 'edit/:name',
              builder: (context, state) => Scaffold(
                body: Text(
                  'Form: ${state.pathParameters['key']} edit '
                  '${state.pathParameters['name']}',
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        mastersCatalogProvider.overrideWith((ref) async => [def]),
        recordsOverride,
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
