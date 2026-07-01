import 'package:bude_inventory/features/masters/data/masters_remote_data_source.dart';
import 'package:bude_inventory/features/masters/domain/master_def.dart';
import 'package:bude_inventory/features/masters/presentation/master_form_screen.dart';
import 'package:bude_inventory/features/masters/presentation/providers/masters_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _warehouseDef = MasterDef(
  key: 'warehouse',
  label: 'Warehouses',
  doctype: 'Warehouse',
  canDisable: true,
  fields: [
    MasterField(
      name: 'warehouse_name',
      label: 'Warehouse Name',
      type: 'text',
      required: true,
    ),
    MasterField(
      name: 'company',
      label: 'Company',
      type: 'link',
      required: true,
      link: 'Company',
    ),
    MasterField(
      name: 'is_group',
      label: 'Is Group',
      type: 'check',
      required: false,
    ),
    MasterField(
      name: 'account_type',
      label: 'Account Type',
      type: 'select',
      required: false,
      options: ['Stock', 'Fixed Asset'],
    ),
    MasterField(
      name: 'opening_date',
      label: 'Opening Date',
      type: 'date',
      required: false,
    ),
    MasterField(
      name: 'capacity',
      label: 'Capacity',
      type: 'number',
      required: false,
    ),
  ],
);

class _FakeMastersDataSource extends MastersRemoteDataSource {
  final List<(String, Map<String, dynamic>)> createCalls = [];
  final List<(String, String, Map<String, dynamic>)> updateCalls = [];
  final List<(String, String?)> linkOptionCalls = [];
  Object? createError;

  _FakeMastersDataSource() : super(Dio());

  @override
  Future<String> create(String master, Map<String, dynamic> values) async {
    if (createError != null) throw createError!;
    createCalls.add((master, values));
    return 'Floor - A';
  }

  @override
  Future<void> update(
    String master,
    String name,
    Map<String, dynamic> values,
  ) async {
    updateCalls.add((master, name, values));
  }

  @override
  Future<List<String>> linkOptions(String doctype, {String? search}) async {
    linkOptionCalls.add((doctype, search));
    return const ['Bude Global'];
  }
}

void main() {
  Future<_FakeMastersDataSource> pumpCreateForm(WidgetTester tester) async {
    final ds = _FakeMastersDataSource();
    await tester.pumpWidget(_Host(dataSource: ds));
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return ds;
  }

  bool saveEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    return button.onPressed != null;
  }

  testWidgets('renders every field type with required markers', (
    tester,
  ) async {
    await pumpCreateForm(tester);

    expect(find.text('Warehouse Name *'), findsOneWidget);
    expect(find.text('Company *'), findsOneWidget);
    expect(find.text('Is Group'), findsOneWidget);
    expect(find.text('Account Type'), findsOneWidget);
    expect(find.text('Opening Date'), findsOneWidget);
    expect(find.text('Capacity'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets(
    'Save is gated by required fields; check and select fields are interactive',
    (tester) async {
      await pumpCreateForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Warehouse Name *'),
        'Floor',
      );
      await tester.pump();
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(
        find.widgetWithText(TextField, 'Company *'),
        'Bude Global',
      );
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Is Group'));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixed Asset').last);
      await tester.pump();
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'create submits the collected payload, shows Saved, and pops',
    (tester) async {
      final ds = await pumpCreateForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Warehouse Name *'),
        'Floor',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Company *'),
        'Bude Global',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Capacity'),
        '12.5',
      );
      await tester.pump();

      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(ds.createCalls, hasLength(1));
      final (master, values) = ds.createCalls.single;
      expect(master, 'warehouse');
      expect(values, {
        'warehouse_name': 'Floor',
        'company': 'Bude Global',
        'is_group': false,
        'capacity': 12.5,
      });
      expect(find.text('Open'), findsOneWidget); // popped back to base
    },
  );

  testWidgets(
    'invalid number text is submitted as the raw string, not omitted',
    (tester) async {
      final ds = await pumpCreateForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Warehouse Name *'),
        'Floor',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Company *'),
        'Bude Global',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Capacity'), 'abc');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(ds.createCalls.single.$2['capacity'], 'abc');
    },
  );

  testWidgets(
    'create failure shows an error snackbar and leaves the form open',
    (tester) async {
      final ds = _FakeMastersDataSource()
        ..createError = Exception('validation failed');
      await tester.pumpWidget(_Host(dataSource: ds));
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Warehouse Name *'),
        'Floor',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Company *'),
        'Bude Global',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('validation failed'), findsOneWidget);
      expect(find.text('Warehouse Name *'), findsOneWidget); // still on form
      expect(saveEnabled(tester), isTrue); // re-enabled after failure
    },
  );

  testWidgets('edit mode pre-fills fields from the existing record', (
    tester,
  ) async {
    final ds = _FakeMastersDataSource();
    await tester.pumpWidget(
      _Host(
        dataSource: ds,
        recordName: 'Floor - A',
        recordValues: const {
          'warehouse_name': 'Floor',
          'company': 'Bude Global',
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Warehouse Name *'),
          )
          .controller!
          .text,
      'Floor',
    );
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(ds.updateCalls, hasLength(1));
    final (master, name, values) = ds.updateCalls.single;
    expect(master, 'warehouse');
    expect(name, 'Floor - A');
    expect(values['warehouse_name'], 'Floor');
  });

  testWidgets('link field queries linkOptions as the user types', (
    tester,
  ) async {
    final ds = await pumpCreateForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Company *'),
      'bud',
    );
    await tester.pump();
    await tester.pump();

    expect(
      ds.linkOptionCalls.any((c) => c.$1 == 'Company' && c.$2 == 'bud'),
      isTrue,
    );
  });

  testWidgets('unknown master key shows a not-found state', (tester) async {
    await tester.pumpWidget(_Host(dataSource: _FakeMastersDataSource(), masterKey: 'nope'));
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Unknown master.'), findsOneWidget);
  });

  testWidgets('catalog load failure shows an error state', (tester) async {
    await tester.pumpWidget(
      _Host(
        dataSource: _FakeMastersDataSource(),
        catalogError: Exception('offline'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load form: Exception: offline'),
      findsOneWidget,
    );
  });

  testWidgets('record load failure (edit mode) shows an error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        dataSource: _FakeMastersDataSource(),
        recordName: 'Floor - A',
        recordError: Exception('not found'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load record: Exception: not found'),
      findsOneWidget,
    );
  });
}

class _Host extends StatelessWidget {
  final MastersRemoteDataSource dataSource;
  final String masterKey;
  final String? recordName;
  final Map<String, dynamic>? recordValues;
  final Object? catalogError;
  final Object? recordError;

  const _Host({
    required this.dataSource,
    this.masterKey = 'warehouse',
    this.recordName,
    this.recordValues,
    this.catalogError,
    this.recordError,
  });

  @override
  Widget build(BuildContext context) {
    final openPath = recordName == null
        ? '/masters/$masterKey/new'
        : '/masters/$masterKey/edit/${Uri.encodeComponent(recordName!)}';

    final router = GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(openPath),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/masters/:key/new',
          builder: (context, state) =>
              MasterFormScreen(masterKey: state.pathParameters['key']!),
        ),
        GoRoute(
          path: '/masters/:key/edit/:name',
          builder: (context, state) => MasterFormScreen(
            masterKey: state.pathParameters['key']!,
            recordName: Uri.decodeComponent(state.pathParameters['name']!),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        mastersDataSourceProvider.overrideWithValue(dataSource),
        mastersCatalogProvider.overrideWith(
          (ref) async => catalogError != null
              ? throw catalogError!
              : const [_warehouseDef],
        ),
        if (recordName != null)
          masterRecordProvider.overrideWith(
            (ref, args) async =>
                recordError != null ? throw recordError! : recordValues!,
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
