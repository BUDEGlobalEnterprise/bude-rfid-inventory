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
        'source_location': 'Rack 1 - A',
        'target_warehouse': 'Floor - A',
        'target_location': 'Staging - A',
        'items': [
          {
            'item_code': 'A',
            'qty': 2,
            'allocations': [
              {
                'qty': 2,
                'batch_no': 'B-001',
                'serial_nos': ['SN-001', 'SN-002'],
              },
            ],
          },
          {'item_code': 'B', 'qty': 3},
        ],
      },
    );
    final failedId = await queue.enqueue(
      type: 'stock_receipt',
      payload: {
        'target_warehouse': 'Receiving - A',
        'target_location': 'Receiving Rack 1 - A',
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
    await queue.enqueue(
      type: 'stock_reconciliation',
      payload: {
        'warehouse': 'Stores - A',
        'location': 'Rack Count 1 - A',
        'counts': [
          {'item_code': 'D', 'qty': 7},
        ],
      },
    );
    await queue.enqueue(
      type: 'sales_order_dispatch',
      payload: {
        'sales_order': 'SO-001',
        'customer': 'Acme',
        'source_warehouse': 'Stores - A',
        'source_location': 'Rack 1 - A',
        'items': [
          {'sales_order_item': 'SOI-1', 'item_code': 'D', 'qty': 4},
        ],
      },
    );

    await tester.pumpWidget(_TestHost(box: box));
    await tester.pump();

    expect(find.text('Waiting to sync (3)'), findsOneWidget);
    expect(find.text('Failed (1)'), findsOneWidget);
    expect(find.text('Stock transfer'), findsOneWidget);
    expect(find.text('Goods receipt'), findsOneWidget);
    expect(find.text('Stock count'), findsOneWidget);
    expect(find.text('Sales Order dispatch'), findsOneWidget);
    expect(
      find.textContaining(
        'Stores - A / Rack 1 - A -> Floor - A / Staging - A',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Receiving - A / Receiving Rack 1 - A'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Stores - A / Rack Count 1 - A'),
      findsOneWidget,
    );
    expect(find.textContaining('SO-001'), findsOneWidget);
    expect(find.textContaining('Acme'), findsOneWidget);
    expect(find.textContaining('PO PO-0001'), findsOneWidget);
    expect(find.textContaining('Batch B-001'), findsOneWidget);
    expect(find.textContaining('2 serials'), findsOneWidget);
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
