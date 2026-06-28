import 'package:equatable/equatable.dart';

class SalesOrderSummary extends Equatable {
  final String name;
  final String? customer;
  final String? transactionDate;
  final String? deliveryDate;
  final String? status;
  final String? company;
  final int itemCount;
  final double pendingQty;

  const SalesOrderSummary({
    required this.name,
    this.customer,
    this.transactionDate,
    this.deliveryDate,
    this.status,
    this.company,
    this.itemCount = 0,
    this.pendingQty = 0,
  });

  @override
  List<Object?> get props => [
        name,
        customer,
        transactionDate,
        deliveryDate,
        status,
        company,
        itemCount,
        pendingQty,
      ];
}

class SalesOrderLine extends Equatable {
  final String salesOrderItem;
  final String itemCode;
  final String? itemName;
  final double pendingQty;
  final String? stockUom;
  final String? warehouse;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final bool createNewBatch;

  const SalesOrderLine({
    required this.salesOrderItem,
    required this.itemCode,
    required this.pendingQty,
    this.itemName,
    this.stockUom,
    this.warehouse,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.createNewBatch = false,
  });

  @override
  List<Object?> get props => [
        salesOrderItem,
        itemCode,
        itemName,
        pendingQty,
        stockUom,
        warehouse,
        hasBatchNo,
        hasSerialNo,
        createNewBatch,
      ];
}

class SalesOrderDetail extends SalesOrderSummary {
  final List<SalesOrderLine> items;

  const SalesOrderDetail({
    required super.name,
    super.customer,
    super.transactionDate,
    super.deliveryDate,
    super.status,
    super.company,
    super.itemCount,
    super.pendingQty,
    this.items = const [],
  });

  @override
  List<Object?> get props => [...super.props, items];
}
