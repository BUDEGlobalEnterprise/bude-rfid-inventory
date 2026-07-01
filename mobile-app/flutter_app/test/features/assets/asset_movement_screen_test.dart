import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/assets/data/asset_op_submitters.dart';
import 'package:bude_inventory/features/assets/data/asset_remote_data_source.dart';
import 'package:bude_inventory/features/assets/presentation/asset_movement_screen.dart';
import 'package:bude_inventory/features/assets/presentation/providers/asset_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

const _locations = [
  AssetLocation(name: 'Floor'),
  AssetLocation(name: 'Yard'),
];

void main() {
  Future<SyncQueue> pumpMovementScreen(
    WidgetTester tester, {
    String? initialAsset,
    Override? locationsOverride,
  }) async {
    final queue = SyncQueue(box: FakeBox());
    await tester.pumpWidget(
      _Host(
        queue: queue,
        initialAsset: initialAsset,
        locationsOverride: locationsOverride,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return queue;
  }

  bool submitEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Queue movement'),
    );
    return button.onPressed != null;
  }

  testWidgets('initialAsset pre-fills the asset list', (tester) async {
    await pumpMovementScreen(tester, initialAsset: 'AST-001');

    expect(find.text('AST-001'), findsOneWidget);
  });

  testWidgets('Issue purpose reveals the employee field; Transfer does not', (
    tester,
  ) async {
    await pumpMovementScreen(tester);

    expect(find.text('To employee (ID)'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue (check-out)').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('To employee (ID)'), findsOneWidget);
  });

  testWidgets('submit stays disabled until required fields are set', (
    tester,
  ) async {
    await pumpMovementScreen(tester);

    // No assets yet, Transfer purpose with no target location.
    expect(submitEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, 'AST-001');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Asset added but Transfer still needs a target location.
    expect(submitEnabled(tester), isFalse);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Floor').last);
    await tester.pump();
    await tester.pump();

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('Issue purpose accepts employee alone without a location', (
    tester,
  ) async {
    await pumpMovementScreen(tester, initialAsset: 'AST-001');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue (check-out)').last);
    await tester.pump();
    await tester.pump();

    expect(submitEnabled(tester), isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'To employee (ID)'), 'EMP-001');
    await tester.pump();

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('duplicate asset add is a no-op and rows can be removed', (
    tester,
  ) async {
    await pumpMovementScreen(tester);

    final assetField = find.byType(TextField).first;
    final addButton = find.byIcon(Icons.add);
    await tester.enterText(assetField, 'AST-001');
    await tester.tap(addButton);
    await tester.pump();
    await tester.enterText(assetField, 'AST-001');
    await tester.tap(addButton);
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'AST-001'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'AST-001'), findsNothing);
  });

  testWidgets(
    'queue-first submit enqueues an asset_movement op with the right shape and pops',
    (tester) async {
      final queue = await pumpMovementScreen(tester, initialAsset: 'AST-001');

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Floor').last);
      await tester.pump();
      await tester.pump();

      expect(submitEnabled(tester), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Queue movement'));
      await tester.pumpAndSettle();

      final ops = queue.all();
      expect(ops, hasLength(1));
      expect(ops.single.type, kAssetMovementOpType);
      expect(ops.single.status, OpStatus.pending);
      expect(ops.single.payload, {
        'assets': ['AST-001'],
        'purpose': 'Transfer',
        'target_location': 'Floor',
      });

      // Popped back to the base route.
      expect(find.text('Open'), findsOneWidget);

      await queue.dispose();
    },
  );

  testWidgets(
    'locations failing to load leaves the dropdown empty without crashing',
    (tester) async {
      await pumpMovementScreen(
        tester,
        initialAsset: 'AST-001',
        locationsOverride: assetLocationsProvider.overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      );

      expect(submitEnabled(tester), isFalse);
    },
  );
}

class _Host extends StatelessWidget {
  final SyncQueue queue;
  final String? initialAsset;
  final Override? locationsOverride;

  const _Host({
    required this.queue,
    this.initialAsset,
    this.locationsOverride,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/asset-movement'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/asset-movement',
          builder: (context, state) =>
              AssetMovementScreen(initialAsset: initialAsset),
        ),
      ],
    );

    final network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    return ProviderScope(
      overrides: [
        syncQueueProvider.overrideWithValue(queue),
        networkInfoProvider.overrideWithValue(network),
        locationsOverride ??
            assetLocationsProvider.overrideWith((ref) async => _locations),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
