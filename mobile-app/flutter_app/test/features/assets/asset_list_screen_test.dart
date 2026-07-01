import 'dart:async';

import 'package:bude_inventory/core/ui/loading_shimmer.dart';
import 'package:bude_inventory/features/assets/data/asset_remote_data_source.dart';
import 'package:bude_inventory/features/assets/presentation/asset_list_screen.dart';
import 'package:bude_inventory/features/assets/presentation/providers/asset_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _assets = [
  AssetSummary(name: 'AST-001', assetName: 'Forklift 1', location: 'Yard', status: 'Submitted'),
];

void main() {
  testWidgets('shows loading then rendered rows', (tester) async {
    final completer = Completer<List<AssetSummary>>();
    await tester.pumpWidget(
      _Host(
        listOverride: assetListProvider.overrideWith((ref, filter) => completer.future),
      ),
    );
    await tester.pump();

    expect(find.byType(ShimmerList), findsOneWidget);

    completer.complete(_assets);
    await tester.pump();
    await tester.pump();

    expect(find.text('Forklift 1'), findsOneWidget);
    expect(find.textContaining('AST-001'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no matches', (tester) async {
    await tester.pumpWidget(
      _Host(
        listOverride: assetListProvider.overrideWith((ref, filter) async => const []),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No assets found'), findsOneWidget);
  });

  testWidgets('shows a load-failure message ("unknown asset" find failure)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        listOverride: assetListProvider.overrideWith(
          (ref, filter) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Failed to load assets: Exception: offline'),
      findsOneWidget,
    );
  });

  testWidgets('search submit re-queries with the trimmed search term', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        listOverride: assetListProvider.overrideWith(
          (ref, filter) async => filter.search == 'fork'
              ? _assets
              : const <AssetSummary>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No assets found'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '  fork  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(find.text('Forklift 1'), findsOneWidget);
  });

  testWidgets('status filter chip re-queries with the selected status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        listOverride: assetListProvider.overrideWith(
          (ref, filter) async => filter.status == 'In Maintenance'
              ? _assets
              : const <AssetSummary>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No assets found'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Maintenance').last);
    await tester.pumpAndSettle();

    expect(find.text('Forklift 1'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to the URI-encoded asset detail route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouterHost(
        listOverride: assetListProvider.overrideWith(
          (ref, filter) async => const [
            AssetSummary(name: 'AST 001', assetName: 'Forklift 1'),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Forklift 1'));
    await tester.pumpAndSettle();

    expect(find.text('Detail: AST 001'), findsOneWidget);
  });
}

class _Host extends StatelessWidget {
  final Override listOverride;

  const _Host({required this.listOverride});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        listOverride,
        assetCategoriesProvider.overrideWith((ref) async => const []),
        assetLocationsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AssetListScreen(),
      ),
    );
  }
}

class _RouterHost extends StatelessWidget {
  final Override listOverride;

  const _RouterHost({required this.listOverride});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/assets',
      routes: [
        GoRoute(
          path: '/assets',
          builder: (context, state) => const AssetListScreen(),
        ),
        GoRoute(
          path: '/assets/:name',
          builder: (context, state) => Scaffold(
            body: Text('Detail: ${state.pathParameters['name']}'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        listOverride,
        assetCategoriesProvider.overrideWith((ref) async => const []),
        assetLocationsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
