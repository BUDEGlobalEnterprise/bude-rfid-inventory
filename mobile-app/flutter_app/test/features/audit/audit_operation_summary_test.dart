import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/audit/domain/audit_operation_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes stock transfer locations, quantities, tracking, and approval', () {
    final op = PendingOperation(
      id: 'op-transfer',
      type: kStockTransferAuditType,
      status: OpStatus.pendingApproval,
      createdAt: DateTime.utc(2026, 6, 30),
      payload: const {
        'source_warehouse': 'Stores - A',
        'source_location': 'Rack 1 - A',
        'target_warehouse': 'Floor - A',
        'target_location': 'Staging - A',
        'approval_reason': 'Transfer quantity 12 exceeds threshold 10.',
        'company': 'Bude Global',
        'items': [
          {
            'item_code': 'ITEM-A',
            'qty': 7,
            'allocations': [
              {
                'qty': 2,
                'batch_no': 'BATCH-001',
                'serial_nos': ['SN-001', 'SN-002'],
              },
            ],
          },
          {'item_code': 'ITEM-B', 'qty': 5},
        ],
      },
    );

    final summary = summarizeOperation(op);

    expect(summary.title, 'Stock transfer');
    expect(
      summary.subtitle,
      contains('Stores - A / Rack 1 - A -> Floor - A / Staging - A'),
    );
    expect(summary.subtitle, contains('2 lines / qty 12'));
    expect(summary.tracking, contains('Batch BATCH-001'));
    expect(summary.tracking, contains('2 serials'));
    expect(summary.company, 'Bude Global');
    expect(summary.approvalReason, 'Transfer quantity 12 exceeds threshold 10.');
    expect(approvalMessageFor(op), 'Transfer quantity 12 exceeds threshold 10.');
  });

  test('summarizes approved stock count metadata', () {
    final op = PendingOperation(
      id: 'op-count',
      type: kStockReconciliationAuditType,
      status: OpStatus.pending,
      createdAt: DateTime.utc(2026, 6, 30),
      payload: const {
        'warehouse': 'Stores - A',
        'location': 'Rack Count 1 - A',
        'approved_by': 'manager@example.com',
        'approved_at': '2026-06-30T10:00:00.000Z',
        'counts': [
          {'item_code': 'ITEM-A', 'qty': 4},
        ],
      },
    );

    final summary = summarizeOperation(op);

    expect(summary.title, 'Stock count');
    expect(summary.subtitle, contains('Stores - A / Rack Count 1 - A'));
    expect(summary.quantitySummary, '1 line / qty 4');
    expect(summary.approvedBy, 'manager@example.com');
    expect(summary.approvedAt, '2026-06-30T10:00:00.000Z');
    expect(erpRouteSegmentForOperation(op.type), 'stock-reconciliation');
  });
}
