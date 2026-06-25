import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/sync/presentation/pending_queue_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_box.dart';

void main() {
  testWidgets('groups queued operations by status with readable summaries', (
    tester,
  ) async {
    final box = FakeBox();
    final queue = SyncQueue(box: box);
    addTearDown(queue.dispose);

    await queue.enqueue(
      type: 'stock_transfer',
      payload: {
        'source_warehouse': 'Stores - A',
        'target_warehouse': 'Floor - A',
        'items': [
          {'item_code': 'A', 'qty': 2},
          {'item_code': 'B', 'qty': 3},
        ],
      },
    );
    final failedId = await queue.enqueue(
      type: 'stock_receipt',
      payload: {
        'target_warehouse': 'Receiving - A',
        'against_po': 'PO-0001',
        'items': [
          {'item_code': 'C', 'qty': 5},
        ],
      },
    );
    await queue.update(
      queue.getById(failedId)!.copyWith(
            status: OpStatus.failed,
            attempts: 2,
            lastError: 'Network down',
          ),
    );

    await tester.pumpWidget(_TestHost(box: box));
    await tester.pump();

    expect(find.text('Waiting to sync (1)'), findsOneWidget);
    expect(find.text('Failed (1)'), findsOneWidget);
    expect(find.text('Stock transfer'), findsOneWidget);
    expect(find.text('Goods receipt'), findsOneWidget);
    expect(find.textContaining('Stores - A -> Floor - A'), findsOneWidget);
    expect(find.textContaining('PO PO-0001'), findsOneWidget);
    expect(find.text('Network down'), findsOneWidget);
  });

  testWidgets('shows empty state when all operations are complete', (
    tester,
  ) async {
    final box = FakeBox();

    await tester.pumpWidget(_TestHost(box: box));
    await tester.pump();

    expect(find.text('No pending operations'), findsOneWidget);
    expect(find.text('All changes have been synced.'), findsOneWidget);
  });
}

class _TestHost extends StatelessWidget {
  final FakeBox box;
  const _TestHost({required this.box});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [syncBoxProvider.overrideWithValue(box)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PendingQueueScreen(),
      ),
    );
  }
}
