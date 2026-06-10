import 'package:bude_inventory/features/reconciliation/domain/reconciliation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountLine', () {
    test('variance is null when expectedQty unknown', () {
      const line = CountLine(itemCode: 'A', countedQty: 5);
      expect(line.variance, isNull);
    });

    test('variance is counted minus expected', () {
      const line =
          CountLine(itemCode: 'A', countedQty: 5, expectedQty: 7);
      expect(line.variance, -2);
    });

    test('positive variance when counted exceeds expected', () {
      const line =
          CountLine(itemCode: 'A', countedQty: 10, expectedQty: 7);
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
      lines: [
        CountLine(itemCode: 'A', countedQty: 12, expectedQty: 10),
        CountLine(itemCode: 'B', countedQty: 0, expectedQty: 3),
      ],
    );
    expect(draft.toPayload(), {
      'warehouse': 'Stores - X',
      'counts': [
        {'item_code': 'A', 'qty': 12.0},
        {'item_code': 'B', 'qty': 0.0},
      ],
    });
  });
}
