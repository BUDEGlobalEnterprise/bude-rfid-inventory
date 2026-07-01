import 'package:bude_inventory/core/router/app_router.dart';
import 'package:bude_inventory/features/fulfillment/domain/fulfillment_route_extra.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/labels/domain/label_request.dart';
import 'package:bude_inventory/features/receipt/domain/receipt_route_extra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public routes', () {
    test('only login and settings are public after tenant setup', () {
      expect(isPublicRoute('/login'), isTrue);
      expect(isPublicRoute('/settings'), isTrue);
      expect(isPublicRoute('/'), isFalse);
      expect(isPublicRoute('/lookup'), isFalse);
      expect(isPublicRoute('/sync'), isFalse);
    });
  });

  group('manager-only locations', () {
    test('covers release-critical manager routes', () {
      expect(isManagerOnlyLocation('/masters'), isTrue);
      expect(isManagerOnlyLocation('/masters/item'), isTrue);
      expect(isManagerOnlyLocation('/warehouse/Main%20Stores'), isTrue);
      expect(isManagerOnlyLocation('/analytics'), isTrue);
      expect(isManagerOnlyLocation('/reports'), isTrue);
    });

    test('leaves operator routes unblocked', () {
      expect(isManagerOnlyLocation('/'), isFalse);
      expect(isManagerOnlyLocation('/lookup'), isFalse);
      expect(isManagerOnlyLocation('/scan-session'), isFalse);
      expect(isManagerOnlyLocation('/sync'), isFalse);
      expect(isManagerOnlyLocation('/labels'), isFalse);
      expect(isManagerOnlyLocation('/settings'), isFalse);
    });
  });

  group('reconciliation approval route contract', () {
    test('accepts a non-empty operation id', () {
      expect(reconciliationApprovalOpIdFromExtra('op-123'), 'op-123');
      expect(reconciliationApprovalOpIdFromExtra('  op-123  '), 'op-123');
    });

    test('rejects missing or malformed extras without throwing', () {
      expect(reconciliationApprovalOpIdFromExtra(null), isNull);
      expect(reconciliationApprovalOpIdFromExtra(''), isNull);
      expect(reconciliationApprovalOpIdFromExtra(42), isNull);
      expect(reconciliationApprovalOpIdFromExtra({'op': 'op-123'}), isNull);
    });
  });

  group('label route contract', () {
    test('accepts only a label request extra', () {
      const request = LabelRequest(
        kind: LabelKind.item,
        title: 'Widget',
        primaryCode: 'ITEM-001',
      );

      expect(labelRequestFromRouteExtra(request), request);
      expect(labelRequestFromRouteExtra(null), isNull);
      expect(labelRequestFromRouteExtra({'code': 'ITEM-001'}), isNull);
    });
  });

  group('task launcher route extras', () {
    test('receipt route accepts task metadata and legacy item extras', () {
      const item = Item(itemCode: 'ITEM-001', itemName: 'Widget');
      const taskExtra = ReceiptRouteExtra(
        againstPo: 'PO-001',
        todoName: 'TODO-PO',
      );

      expect(receiptRouteExtraFromRouteExtra(taskExtra), taskExtra);
      expect(receiptRouteExtraFromRouteExtra(item)?.initialItem, item);
      expect(receiptRouteExtraFromRouteExtra(null), isNull);
      expect(receiptRouteExtraFromRouteExtra({'against_po': 'PO-001'}), isNull);
    });

    test('fulfillment route accepts only fulfillment task metadata', () {
      const extra = FulfillmentRouteExtra(todoName: 'TODO-SO');

      expect(fulfillmentRouteExtraFromRouteExtra(extra), extra);
      expect(fulfillmentRouteExtraFromRouteExtra(null), isNull);
      expect(fulfillmentRouteExtraFromRouteExtra('TODO-SO'), isNull);
    });
  });
}
