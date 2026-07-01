import 'package:bude_inventory/features/fulfillment/domain/fulfillment_draft.dart';
import 'package:bude_inventory/features/fulfillment/domain/sales_order.dart';
import 'package:bude_inventory/features/tracking/domain/tracking_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SalesOrderDetail order() => const SalesOrderDetail(
        name: 'SO-001',
        customer: 'Acme',
        company: 'Company A',
        items: [
          SalesOrderLine(
            salesOrderItem: 'SOI-1',
            itemCode: 'ITEM-1',
            itemName: 'Item 1',
            pendingQty: 2,
          ),
          SalesOrderLine(
            salesOrderItem: 'SOI-2',
            itemCode: 'ITEM-2',
            itemName: 'Item 2',
            pendingQty: 1,
          ),
        ],
      );

  test('requires exact pick and pack before dispatch', () {
    var draft = FulfillmentDraft.fromSalesOrder(order())
        .setSource('Stores - A')
        .addPickedItem('ITEM-1', 2)
        .addPickedItem('ITEM-2', 1);

    expect(draft.isPickedExact, isTrue);
    expect(draft.isPackedExact, isFalse);
    expect(draft.canDispatch, isFalse);

    draft = draft.confirmPickedAsPacked();

    expect(draft.isPackedExact, isTrue);
    expect(draft.canDispatch, isTrue);
  });

  test('duplicate scans fill matching sales order lines in order', () {
    final draft = const FulfillmentDraft(
      salesOrder: 'SO-001',
      lines: [
        FulfillmentLine(
          salesOrderItem: 'SOI-1',
          itemCode: 'ITEM',
          requiredQty: 1,
        ),
        FulfillmentLine(
          salesOrderItem: 'SOI-2',
          itemCode: 'ITEM',
          requiredQty: 2,
        ),
      ],
    ).addPickedItem('ITEM', 3);

    expect(draft.lines[0].pickedQty, 1);
    expect(draft.lines[1].pickedQty, 2);
    expect(draft.isPickedExact, isTrue);
  });

  test('payload matches backend create_delivery_note contract', () {
    final draft = FulfillmentDraft.fromSalesOrder(
      order(),
      todoName: 'TODO-SO',
    )
        .setSource('Stores - A')
        .setSourceLocation('Rack 1 - A')
        .addPickedItem('ITEM-1', 2)
        .addPickedItem('ITEM-2', 1)
        .confirmPickedAsPacked();

    expect(draft.toPayload(), {
      'sales_order': 'SO-001',
      'customer': 'Acme',
      'source_warehouse': 'Stores - A',
      'source_location': 'Rack 1 - A',
      'todo_name': 'TODO-SO',
      'items': [
        {'sales_order_item': 'SOI-1', 'item_code': 'ITEM-1', 'qty': 2.0},
        {'sales_order_item': 'SOI-2', 'item_code': 'ITEM-2', 'qty': 1.0},
      ],
      'company': 'Company A',
    });
  });

  test('dispatch blocks tracked lines until allocations are complete', () {
    const trackedOrder = SalesOrderDetail(
      name: 'SO-TRACKED',
      customer: 'Acme',
      items: [
        SalesOrderLine(
          salesOrderItem: 'SOI-1',
          itemCode: 'SERIAL',
          pendingQty: 1,
          hasSerialNo: true,
        ),
      ],
    );

    var draft = FulfillmentDraft.fromSalesOrder(trackedOrder)
        .setSource('Stores - A')
        .addPickedItem('SERIAL', 1)
        .confirmPickedAsPacked();

    expect(draft.canDispatch, isFalse);

    draft = draft.setAllocations('SOI-1', const [
      TrackingAllocation(qty: 1, serialNos: ['SN-001']),
    ]);

    expect(draft.canDispatch, isTrue);
    expect(draft.toPayload()['items'], [
      {
        'sales_order_item': 'SOI-1',
        'item_code': 'SERIAL',
        'qty': 1.0,
        'allocations': [
          {
            'qty': 1.0,
            'serial_nos': ['SN-001'],
          },
        ],
      },
    ]);
  });
}
