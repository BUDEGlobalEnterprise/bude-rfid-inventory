import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/labels/domain/label_request.dart';
import 'package:bude_inventory/features/labels/domain/label_request_builders.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('item request carries item label metadata', () {
    final request = itemLabelRequest(
      const Item(
        itemCode: 'ITEM-001',
        itemName: 'Widget',
        stockUom: 'Nos',
        itemGroup: 'Finished Goods',
      ),
    );

    expect(request.kind, LabelKind.item);
    expect(request.primaryCode, 'ITEM-001');
    expect(request.title, 'Widget');
    expect(request.metadata, {
      'UOM': 'Nos',
      'Group': 'Finished Goods',
    });
  });

  test('receipt draft request serializes local queued receipt fields', () {
    final request = receiptLabelRequestFromDraft(
      opId: 'op-123',
      draft: const ReceiptDraft(
        targetWarehouse: 'Receiving - A',
        targetLocation: 'Dock 1 - A',
        againstPo: 'PO-0001',
        company: 'Bude Global',
        lines: [
          ReceiptLine(itemCode: 'ITEM-A', qty: 2),
          ReceiptLine(itemCode: 'ITEM-B', qty: 3),
        ],
      ),
    );

    expect(request.kind, LabelKind.receipt);
    expect(request.primaryCode, 'op-123');
    expect(request.metadata['Target'], 'Receiving - A');
    expect(request.metadata['Location'], 'Dock 1 - A');
    expect(request.metadata['PO'], 'PO-0001');
    expect(request.metadata['Lines'], '2');
    expect(request.metadata['Qty'], '5');
    expect(request.metadata['Company'], 'Bude Global');
    expect(request.barcodeData, contains('"op_id":"op-123"'));
    expect(request.barcodeData, contains('"target_warehouse":"Receiving - A"'));
  });

  test('receipt operation prefers server ref when available', () {
    final request = receiptLabelRequestFromOperation(
      PendingOperation(
        id: 'op-456',
        type: 'stock_receipt',
        status: OpStatus.succeeded,
        createdAt: DateTime.utc(2026),
        serverRef: 'PREC-0001',
        payload: const {
          'target_warehouse': 'Receiving - A',
          'items': [
            {'item_code': 'ITEM-A', 'qty': 1},
          ],
        },
      ),
    );

    expect(request.primaryCode, 'PREC-0001');
    expect(request.receiptOpId, 'op-456');
    expect(request.receiptServerRef, 'PREC-0001');
  });

  test('pallet IDs are deterministic with injected inputs and unique locally', () {
    expect(
      generatePalletId(
        now: DateTime.utc(2026, 6, 30, 1, 2, 3),
        sequence: 35,
      ),
      'PAL-20260630010203-00Z',
    );

    final first = generatePalletId(now: DateTime.utc(2026, 6, 30));
    final second = generatePalletId(now: DateTime.utc(2026, 6, 30));
    expect(first, isNot(second));
  });

  test('validation blocks empty codes and zero quantity', () {
    expect(
      validateLabelRequest(
        const LabelRequest(
          kind: LabelKind.pallet,
          title: 'Pallet',
          primaryCode: '',
        ),
      ),
      'Enter a pallet code before printing.',
    );
    expect(
      validateLabelRequest(
        const LabelRequest(
          kind: LabelKind.item,
          title: 'Item',
          primaryCode: 'ITEM-001',
          quantity: 0,
        ),
      ),
      'Quantity must be at least 1.',
    );
  });
}
