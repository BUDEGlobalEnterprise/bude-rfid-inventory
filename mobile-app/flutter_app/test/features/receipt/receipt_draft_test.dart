import 'package:bude_inventory/features/receipt/domain/receipt_draft.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSubmittable', () {
    test('false when target missing', () {
      const draft = ReceiptDraft(
        lines: [ReceiptLine(itemCode: 'A', qty: 1)],
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('false when no lines', () {
      const draft = ReceiptDraft(targetWarehouse: 'A');
      expect(draft.isSubmittable, isFalse);
    });

    test('false when any line has zero/negative qty', () {
      const draft = ReceiptDraft(
        targetWarehouse: 'A',
        lines: [
          ReceiptLine(itemCode: 'X', qty: 1),
          ReceiptLine(itemCode: 'Y', qty: 0),
        ],
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('true when target + positive-qty lines present', () {
      const draft = ReceiptDraft(
        targetWarehouse: 'A',
        lines: [ReceiptLine(itemCode: 'X', qty: 1)],
      );
      expect(draft.isSubmittable, isTrue);
    });
  });

  group('toPayload', () {
    test('omits against_po when null (Material Receipt mode)', () {
      const draft = ReceiptDraft(
        targetWarehouse: 'Tgt - X',
        targetLocation: 'Rack 1 - X',
        lines: [ReceiptLine(itemCode: 'A', qty: 2)],
      );
      final payload = draft.toPayload();
      expect(payload.containsKey('against_po'), isFalse);
      expect(payload['target_warehouse'], 'Tgt - X');
      expect(payload['target_location'], 'Rack 1 - X');
      expect(payload['items'], [
        {'item_code': 'A', 'qty': 2.0},
      ]);
    });

    test('includes against_po when set (Purchase Receipt mode)', () {
      const draft = ReceiptDraft(
        targetWarehouse: 'Tgt - X',
        againstPo: 'PO-001',
        todoName: 'TODO-PO',
        lines: [ReceiptLine(itemCode: 'A', qty: 1)],
      );
      expect(draft.toPayload()['against_po'], 'PO-001');
      expect(draft.toPayload()['todo_name'], 'TODO-PO');
    });
  });

  test('copyWith(clearAgainstPo: true) drops the PO', () {
    const draft = ReceiptDraft(
      targetWarehouse: 'A',
      againstPo: 'PO-001',
    );
    expect(draft.copyWith(clearAgainstPo: true).againstPo, isNull);
  });

  test('receipt serializes new batch allocation with expiry', () {
    const draft = ReceiptDraft(
      targetWarehouse: 'Receiving - A',
      lines: [
        ReceiptLine(
          itemCode: 'BATCHED',
          qty: 5,
          hasBatchNo: true,
          allocations: [
            TrackingAllocation(
              qty: 5,
              batchNo: 'B-001',
              expiryDate: '2030-12-31',
            ),
          ],
        ),
      ],
    );

    expect(draft.isSubmittable, isTrue);
    expect(draft.toPayload()['items'], [
      {
        'item_code': 'BATCHED',
        'qty': 5.0,
        'allocations': [
          {
            'qty': 5.0,
            'batch_no': 'B-001',
            'expiry_date': '2030-12-31',
          },
        ],
      },
    ]);
  });
}
