import 'dart:async';

import 'package:bude_inventory/core/ui/loading_shimmer.dart';
import 'package:bude_inventory/features/masters/domain/master_def.dart';
import 'package:bude_inventory/features/masters/presentation/masters_hub_screen.dart';
import 'package:bude_inventory/features/masters/presentation/providers/masters_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _catalog = [
  MasterDef(
    key: 'company',
    label: 'Companies',
    doctype: 'Company',
    canDisable: false,
    fields: [],
  ),
  MasterDef(
    key: 'warehouse',
    label: 'Warehouses',
    doctype: 'Warehouse',
    canDisable: true,
    fields: [],
  ),
];

void main() {
  testWidgets('shows loading then the master catalog', (tester) async {
    final completer = Completer<List<MasterDef>>();
    await tester.pumpWidget(
      _Host(catalogOverride: mastersCatalogProvider.overrideWith(
        (ref) => completer.future,
      )),
    );
    await tester.pump();

    expect(find.byType(ShimmerList), findsOneWidget);

    completer.complete(_catalog);
    await tester.pump();
    await tester.pump();

    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Warehouses'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);
  });

  testWidgets('shows empty state when no masters are registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        catalogOverride:
            mastersCatalogProvider.overrideWith((ref) async => const []),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No masters available'), findsOneWidget);
  });

  testWidgets('shows a load-failure message', (tester) async {
    await tester.pumpWidget(
      _Host(
        catalogOverride: mastersCatalogProvider.overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Failed to load masters: Exception: offline'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a master navigates to its records route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(
        catalogOverride:
            mastersCatalogProvider.overrideWith((ref) async => _catalog),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Warehouses'));
    await tester.pumpAndSettle();

    expect(find.text('Records for warehouse'), findsOneWidget);
  });
}

class _Host extends StatelessWidget {
  final Override catalogOverride;

  const _Host({required this.catalogOverride});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [catalogOverride],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MastersHubScreen(),
      ),
    );
  }
}

class _RouterHost extends StatelessWidget {
  final Override catalogOverride;

  const _RouterHost({required this.catalogOverride});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/masters',
      routes: [
        GoRoute(
          path: '/masters',
          builder: (context, state) => const MastersHubScreen(),
        ),
        GoRoute(
          path: '/masters/:key',
          builder: (context, state) => Scaffold(
            body: Text('Records for ${state.pathParameters['key']}'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [catalogOverride],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
