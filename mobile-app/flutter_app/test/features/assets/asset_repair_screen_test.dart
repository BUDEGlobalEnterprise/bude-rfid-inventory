import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/assets/data/asset_op_submitters.dart';
import 'package:bude_inventory/features/assets/presentation/asset_repair_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

void main() {
  Future<SyncQueue> pumpRepairScreen(
    WidgetTester tester, {
    String? initialAsset,
  }) async {
    final queue = SyncQueue(box: FakeBox());
    await tester.pumpWidget(_Host(queue: queue, initialAsset: initialAsset));
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return queue;
  }

  bool submitEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Queue repair report'),
    );
    return button.onPressed != null;
  }

  testWidgets('initialAsset pre-fills the asset field', (tester) async {
    await pumpRepairScreen(tester, initialAsset: 'AST-001');

    expect(find.text('AST-001'), findsOneWidget);
  });

  testWidgets('submit stays disabled until asset name is set', (
    tester,
  ) async {
    await pumpRepairScreen(tester);

    expect(submitEnabled(tester), isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Asset name'),
      'AST-001',
    );
    await tester.pump();

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets(
    'queue-first submit includes a parsed repair cost and pops',
    (tester) async {
      final queue = await pumpRepairScreen(tester, initialAsset: 'AST-001');

      await tester.enterText(
        find.widgetWithText(TextField, 'Failure description'),
        'Motor noise',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Estimated repair cost (optional)'),
        '150.5',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Queue repair report'));
      await tester.pumpAndSettle();

      final ops = queue.all();
      expect(ops, hasLength(1));
      expect(ops.single.type, kAssetRepairOpType);
      expect(ops.single.status, OpStatus.pending);
      expect(ops.single.payload, {
        'asset': 'AST-001',
        'description': 'Motor noise',
        'repair_cost': 150.5,
      });

      expect(find.text('Open'), findsOneWidget);

      await queue.dispose();
    },
  );

  testWidgets(
    'invalid repair cost text is silently omitted from the payload',
    (tester) async {
      final queue = await pumpRepairScreen(tester, initialAsset: 'AST-001');

      await tester.enterText(
        find.widgetWithText(TextField, 'Estimated repair cost (optional)'),
        'not-a-number',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Queue repair report'));
      await tester.pumpAndSettle();

      final ops = queue.all();
      expect(ops.single.payload, {'asset': 'AST-001'});

      await queue.dispose();
    },
  );
}

class _Host extends StatelessWidget {
  final SyncQueue queue;
  final String? initialAsset;

  const _Host({required this.queue, this.initialAsset});

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
                onPressed: () => context.push('/asset-repair'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/asset-repair',
          builder: (context, state) =>
              AssetRepairScreen(initialAsset: initialAsset),
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
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
