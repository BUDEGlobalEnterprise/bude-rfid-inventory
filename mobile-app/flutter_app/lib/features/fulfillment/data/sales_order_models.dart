import '../domain/sales_order.dart';

class SalesOrderSummaryModel extends SalesOrderSummary {
  const SalesOrderSummaryModel({
    required super.name,
    super.customer,
    super.transactionDate,
    super.deliveryDate,
    super.status,
    super.company,
    super.itemCount,
    super.pendingQty,
  });

  factory SalesOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderSummaryModel(
      name: json['name'] as String,
      customer: json['customer'] as String?,
      transactionDate: json['transaction_date']?.toString(),
      deliveryDate: json['delivery_date']?.toString(),
      status: json['status'] as String?,
      company: json['company'] as String?,
      itemCount: ((json['item_count'] as num?) ?? 0).toInt(),
      pendingQty: ((json['pending_qty'] as num?) ?? 0).toDouble(),
    );
  }
}

class SalesOrderLineModel extends SalesOrderLine {
  const SalesOrderLineModel({
    required super.salesOrderItem,
    required super.itemCode,
    required super.pendingQty,
    super.itemName,
    super.stockUom,
    super.warehouse,
    super.hasBatchNo,
    super.hasSerialNo,
    super.createNewBatch,
  });

  factory SalesOrderLineModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderLineModel(
      salesOrderItem: json['sales_order_item'] as String,
      itemCode: json['item_code'] as String,
      itemName: json['item_name'] as String?,
      pendingQty: ((json['pending_qty'] as num?) ?? 0).toDouble(),
      stockUom: json['stock_uom'] as String?,
      warehouse: json['warehouse'] as String?,
      hasBatchNo: _truthy(json['has_batch_no']),
      hasSerialNo: _truthy(json['has_serial_no']),
      createNewBatch: _truthy(json['create_new_batch']),
    );
  }
}

class SalesOrderDetailModel extends SalesOrderDetail {
  const SalesOrderDetailModel({
    required super.name,
    super.customer,
    super.transactionDate,
    super.deliveryDate,
    super.status,
    super.company,
    super.itemCount,
    super.pendingQty,
    super.items,
  });

  factory SalesOrderDetailModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .cast<Map>()
        .map((raw) => SalesOrderLineModel.fromJson(raw.cast<String, dynamic>()))
        .toList();
    return SalesOrderDetailModel(
      name: json['name'] as String,
      customer: json['customer'] as String?,
      transactionDate: json['transaction_date']?.toString(),
      deliveryDate: json['delivery_date']?.toString(),
      status: json['status'] as String?,
      company: json['company'] as String?,
      itemCount: ((json['item_count'] as num?) ?? items.length).toInt(),
      pendingQty: ((json['pending_qty'] as num?) ??
              items.fold<double>(0, (sum, item) => sum + item.pendingQty))
          .toDouble(),
      items: items,
    );
  }
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes', 'y'}
      .contains(value?.toString().trim().toLowerCase());
}
