import 'package:bude_inventory/features/reconciliation/domain/reconciliation_draft.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountLine', () {
    test('variance is null when expectedQty unknown', () {
      const line = CountLine(itemCode: 'A', countedQty: 5);
      expect(line.variance, isNull);
    });

    test('variance is counted minus expected', () {
      const line = CountLine(itemCode: 'A', countedQty: 5, expectedQty: 7);
      expect(line.variance, -2);
    });

    test('positive variance when counted exceeds expected', () {
      const line = CountLine(itemCode: 'A', countedQty: 10, expectedQty: 7);
      expect(line.variance, 3);
    });
  });

  group('ReconciliationDraft.isSubmittable', () {
    test('false without warehouse', () {
      const draft = ReconciliationDraft(
        lines: [CountLine(itemCode: 'A', countedQty: 1)],
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('false with no lines', () {
      const draft = ReconciliationDraft(warehouse: 'X');
      expect(draft.isSubmittable, isFalse);
    });

    test('zero counted qty is allowed', () {
      const draft = ReconciliationDraft(
        warehouse: 'X',
        lines: [CountLine(itemCode: 'A', countedQty: 0)],
      );
      expect(draft.isSubmittable, isTrue);
    });

    test('negative counted qty is rejected', () {
      const draft = ReconciliationDraft(
        warehouse: 'X',
        lines: [CountLine(itemCode: 'A', countedQty: -1)],
      );
      expect(draft.isSubmittable, isFalse);
    });
  });

  test('toPayload matches the create_reconciliation contract', () {
    const draft = ReconciliationDraft(
      warehouse: 'Stores - X',
      location: 'Rack 1 - X',
      lines: [
        CountLine(itemCode: 'A', countedQty: 12, expectedQty: 10),
        CountLine(itemCode: 'B', countedQty: 0, expectedQty: 3),
      ],
    );
    expect(draft.toPayload(), {
      'warehouse': 'Stores - X',
      'location': 'Rack 1 - X',
      'counts': [
        {'item_code': 'A', 'qty': 12.0},
        {'item_code': 'B', 'qty': 0.0},
      ],
    });
  });

  test('tracked count lines require matching allocations', () {
    const draft = ReconciliationDraft(
      warehouse: 'Stores - X',
      lines: [
        CountLine(
          itemCode: 'BATCHED',
          countedQty: 3,
          hasBatchNo: true,
          allocations: [TrackingAllocation(qty: 3, batchNo: 'B-001')],
        ),
      ],
    );

    expect(draft.isSubmittable, isTrue);
    expect(draft.toPayload()['counts'], [
      {
        'item_code': 'BATCHED',
        'qty': 3.0,
        'allocations': [
          {'qty': 3.0, 'batch_no': 'B-001'},
        ],
      },
    ]);
  });
}
