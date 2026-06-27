import 'package:bude_inventory/features/transfer/domain/transfer_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSubmittable', () {
    test('false when source or target missing', () {
      const a = TransferDraft();
      expect(a.isSubmittable, isFalse);

      final withSource = a.copyWith(sourceWarehouse: 'X');
      expect(withSource.isSubmittable, isFalse);
    });

    test('false when source equals target', () {
      const draft = TransferDraft(
        sourceWarehouse: 'Same',
        targetWarehouse: 'Same',
        lines: [TransferLine(itemCode: 'A', qty: 1)],
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('false when no lines', () {
      const draft = TransferDraft(
        sourceWarehouse: 'A',
        targetWarehouse: 'B',
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('false when any line has zero or negative qty', () {
      const draft = TransferDraft(
        sourceWarehouse: 'A',
        targetWarehouse: 'B',
        lines: [
          TransferLine(itemCode: 'X', qty: 1),
          TransferLine(itemCode: 'Y', qty: 0),
        ],
      );
      expect(draft.isSubmittable, isFalse);
    });

    test('true when all required fields valid', () {
      const draft = TransferDraft(
        sourceWarehouse: 'A',
        targetWarehouse: 'B',
        lines: [TransferLine(itemCode: 'X', qty: 2)],
      );
      expect(draft.isSubmittable, isTrue);
    });
  });

  test('toPayload produces the shape the backend expects', () {
    const draft = TransferDraft(
      sourceWarehouse: 'Src - X',
      targetWarehouse: 'Tgt - X',
      sourceLocation: 'Src Rack 1 - X',
      targetLocation: 'Tgt Staging - X',
      lines: [
        TransferLine(itemCode: 'A', qty: 2.5),
        TransferLine(itemCode: 'B', qty: 1),
      ],
    );
    expect(draft.toPayload(), {
      'source_warehouse': 'Src - X',
      'target_warehouse': 'Tgt - X',
      'source_location': 'Src Rack 1 - X',
      'target_location': 'Tgt Staging - X',
      'items': [
        {'item_code': 'A', 'qty': 2.5},
        {'item_code': 'B', 'qty': 1.0},
      ],
    });
  });
}
