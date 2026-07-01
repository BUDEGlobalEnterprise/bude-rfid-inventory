import '../../../core/sync/pending_operation.dart';

const kStockTransferAuditType = 'stock_transfer';
const kStockReceiptAuditType = 'stock_receipt';
const kStockReconciliationAuditType = 'stock_reconciliation';
const kSalesOrderDispatchAuditType = 'sales_order_dispatch';

class AuditOperationSummary {
  final String title;
  final String subtitle;
  final int lineCount;
  final double totalQty;
  final String tracking;
  final String? approvalReason;
  final String? approvedBy;
  final String? approvedAt;
  final String? company;

  const AuditOperationSummary({
    required this.title,
    required this.subtitle,
    required this.lineCount,
    required this.totalQty,
    required this.tracking,
    this.approvalReason,
    this.approvedBy,
    this.approvedAt,
    this.company,
  });

  String get quantitySummary => lineCount == 0
      ? ''
      : '$lineCount line${lineCount == 1 ? '' : 's'}'
          ' / qty ${formatAuditQty(totalQty)}';
}

AuditOperationSummary summarizeOperation(PendingOperation op) {
  final payload = op.payload;
  final lines = _operationLines(payload);
  final totalQty = lines.fold<double>(0, (sum, raw) {
    final qty = raw['qty'];
    return sum + (qty is num ? qty.toDouble() : 0);
  });
  final lineCount = lines.length;
  final qtySummary = lineCount == 0
      ? ''
      : '$lineCount line${lineCount == 1 ? '' : 's'}'
          ' / qty ${formatAuditQty(totalQty)}';
  final tracking = _trackingSummary(lines);
  final company = _string(payload['company']);
  final title = operationTitle(op.type);

  final subtitle = switch (op.type) {
    kStockTransferAuditType => _join([
        _arrow(
          warehouseWithLocation(
            payload['source_warehouse'],
            payload['source_location'],
          ),
          warehouseWithLocation(
            payload['target_warehouse'],
            payload['target_location'],
          ),
        ),
        qtySummary,
        tracking,
        company,
      ]),
    kStockReceiptAuditType => _join([
        warehouseWithLocation(
          payload['target_warehouse'],
          payload['target_location'],
        ),
        if (_string(payload['against_po']).isNotEmpty)
          'PO ${payload['against_po']}',
        qtySummary,
        tracking,
        company,
      ]),
    kStockReconciliationAuditType => _join([
        warehouseWithLocation(payload['warehouse'], payload['location']),
        qtySummary,
        tracking,
        company,
      ]),
    kSalesOrderDispatchAuditType => _join([
        _string(payload['sales_order']),
        _string(payload['customer']),
        warehouseWithLocation(
          payload['source_warehouse'],
          payload['source_location'],
        ),
        qtySummary,
        tracking,
        company,
      ]),
    _ => _join([qtySummary, company]),
  };

  return AuditOperationSummary(
    title: title,
    subtitle: subtitle.isEmpty ? op.id : subtitle,
    lineCount: lineCount,
    totalQty: totalQty,
    tracking: tracking,
    approvalReason: _nonEmpty(payload['approval_reason']),
    approvedBy: _nonEmpty(payload['approved_by']),
    approvedAt: _nonEmpty(payload['approved_at']),
    company: _nonEmpty(company),
  );
}

String approvalMessageFor(PendingOperation op) {
  final summary = summarizeOperation(op);
  if (summary.approvalReason != null) return summary.approvalReason!;
  if (op.status == OpStatus.pendingApproval) {
    return '${summary.title} requires supervisor approval before sync.';
  }
  return '${summary.title} is not waiting for approval.';
}

String operationTitle(String type) => switch (type) {
      kStockTransferAuditType => 'Stock transfer',
      kStockReceiptAuditType => 'Goods receipt',
      kStockReconciliationAuditType => 'Stock count',
      kSalesOrderDispatchAuditType => 'Sales Order dispatch',
      'asset_movement' => 'Asset movement',
      'asset_repair' => 'Asset repair',
      'maintenance_log' => 'Maintenance log',
      _ => type,
    };

String? erpRouteSegmentForOperation(String type) => switch (type) {
      kStockTransferAuditType => 'stock-entry',
      kStockReceiptAuditType => 'purchase-receipt',
      kStockReconciliationAuditType => 'stock-reconciliation',
      kSalesOrderDispatchAuditType => 'delivery-note',
      _ => null,
    };

String warehouseWithLocation(Object? warehouse, Object? location) {
  final parent = _string(warehouse);
  final child = _string(location);
  if (child.isEmpty || child == parent) return parent;
  if (parent.isEmpty) return child;
  return '$parent / $child';
}

String formatAuditQty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

List<Map<dynamic, dynamic>> _operationLines(Map<String, dynamic> payload) {
  final raw = payload['items'] is List
      ? payload['items']
      : (payload['counts'] is List ? payload['counts'] : const []);
  if (raw is! List) return const [];
  return raw.whereType<Map>().toList();
}

String _trackingSummary(List<Map<dynamic, dynamic>> lines) {
  final parts = <String>[];
  for (final raw in lines) {
    final allocations = raw['allocations'];
    if (allocations is! List) continue;
    for (final allocation in allocations.whereType<Map>()) {
      final batch = _string(allocation['batch_no']);
      if (batch.isNotEmpty) parts.add('Batch $batch');
      final serials = allocation['serial_nos'];
      if (serials is List && serials.isNotEmpty) {
        parts.add('${serials.length} serial${serials.length == 1 ? '' : 's'}');
      }
      final expiry = _string(allocation['expiry_date']);
      if (expiry.isNotEmpty) parts.add('Exp $expiry');
    }
  }
  return parts.take(4).join(' / ');
}

String _arrow(Object? from, Object? to) {
  final start = _string(from);
  final end = _string(to);
  if (start.isEmpty && end.isEmpty) return '';
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return '$start -> $end';
}

String _join(Iterable<String> values) =>
    values.where((value) => value.trim().isNotEmpty).join(' - ');

String _string(Object? value) => value?.toString().trim() ?? '';

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
