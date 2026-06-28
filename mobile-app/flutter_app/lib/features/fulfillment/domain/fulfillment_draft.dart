import 'package:equatable/equatable.dart';

import '../../tracking/domain/tracking_allocation.dart';
import 'sales_order.dart';

enum FulfillmentStage { pick, pack, dispatch }

class FulfillmentLine extends Equatable {
  final String salesOrderItem;
  final String itemCode;
  final String? itemName;
  final double requiredQty;
  final String? stockUom;
  final double pickedQty;
  final double packedQty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final List<TrackingAllocation> allocations;

  const FulfillmentLine({
    required this.salesOrderItem,
    required this.itemCode,
    required this.requiredQty,
    this.itemName,
    this.stockUom,
    this.pickedQty = 0,
    this.packedQty = 0,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.allocations = const [],
  });

  factory FulfillmentLine.fromSalesOrderLine(SalesOrderLine line) {
    return FulfillmentLine(
      salesOrderItem: line.salesOrderItem,
      itemCode: line.itemCode,
      itemName: line.itemName,
      requiredQty: line.pendingQty,
      stockUom: line.stockUom,
      hasBatchNo: line.hasBatchNo,
      hasSerialNo: line.hasSerialNo,
    );
  }

  FulfillmentLine copyWith({
    double? pickedQty,
    double? packedQty,
    List<TrackingAllocation>? allocations,
  }) {
    return FulfillmentLine(
      salesOrderItem: salesOrderItem,
      itemCode: itemCode,
      itemName: itemName,
      requiredQty: requiredQty,
      stockUom: stockUom,
      pickedQty: pickedQty ?? this.pickedQty,
      packedQty: packedQty ?? this.packedQty,
      hasBatchNo: hasBatchNo,
      hasSerialNo: hasSerialNo,
      allocations: allocations ?? this.allocations,
    );
  }

  bool get pickedExact => _sameQty(pickedQty, requiredQty);
  bool get packedExact => _sameQty(packedQty, requiredQty);
  double get remainingPick => requiredQty - pickedQty;
  bool get isTrackingComplete => _trackingComplete(
        qty: requiredQty,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations,
      );

  Map<String, dynamic> toPayloadJson() => {
        'sales_order_item': salesOrderItem,
        'item_code': itemCode,
        'qty': requiredQty,
        if (allocations.isNotEmpty)
          'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'sales_order_item': salesOrderItem,
        'item_code': itemCode,
        'item_name': itemName,
        'required_qty': requiredQty,
        'stock_uom': stockUom,
        'picked_qty': pickedQty,
        'packed_qty': packedQty,
        'has_batch_no': hasBatchNo,
        'has_serial_no': hasSerialNo,
        'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  factory FulfillmentLine.fromJson(Map<String, dynamic> json) {
    return FulfillmentLine(
      salesOrderItem: json['sales_order_item'] as String,
      itemCode: json['item_code'] as String,
      itemName: json['item_name'] as String?,
      requiredQty: (json['required_qty'] as num).toDouble(),
      stockUom: json['stock_uom'] as String?,
      pickedQty: ((json['picked_qty'] as num?) ?? 0).toDouble(),
      packedQty: ((json['packed_qty'] as num?) ?? 0).toDouble(),
      hasBatchNo: _truthy(json['has_batch_no']),
      hasSerialNo: _truthy(json['has_serial_no']),
      allocations: (json['allocations'] as List? ?? const [])
          .cast<Map>()
          .map(
            (raw) => TrackingAllocation.fromJson(raw.cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        salesOrderItem,
        itemCode,
        itemName,
        requiredQty,
        stockUom,
        pickedQty,
        packedQty,
        hasBatchNo,
        hasSerialNo,
        allocations,
      ];
}

class FulfillmentDraft extends Equatable {
  final String salesOrder;
  final String? customer;
  final String? company;
  final String? sourceWarehouse;
  final String? sourceLocation;
  final FulfillmentStage stage;
  final List<FulfillmentLine> lines;

  const FulfillmentDraft({
    required this.salesOrder,
    this.customer,
    this.company,
    this.sourceWarehouse,
    this.sourceLocation,
    this.stage = FulfillmentStage.pick,
    this.lines = const [],
  });

  factory FulfillmentDraft.fromSalesOrder(SalesOrderDetail order) {
    return FulfillmentDraft(
      salesOrder: order.name,
      customer: order.customer,
      company: order.company,
      lines: order.items.map(FulfillmentLine.fromSalesOrderLine).toList(),
    );
  }

  FulfillmentDraft copyWith({
    Object? sourceWarehouse = _sentinel,
    Object? sourceLocation = _sentinel,
    FulfillmentStage? stage,
    List<FulfillmentLine>? lines,
  }) {
    return FulfillmentDraft(
      salesOrder: salesOrder,
      customer: customer,
      company: company,
      sourceWarehouse: sourceWarehouse == _sentinel
          ? this.sourceWarehouse
          : sourceWarehouse as String?,
      sourceLocation: sourceLocation == _sentinel
          ? this.sourceLocation
          : sourceLocation as String?,
      stage: stage ?? this.stage,
      lines: lines ?? this.lines,
    );
  }

  bool get isPickedExact =>
      lines.isNotEmpty && lines.every((l) => l.pickedExact);
  bool get isPackedExact =>
      lines.isNotEmpty && lines.every((l) => l.packedExact);
  bool get canDispatch =>
      sourceWarehouse != null &&
      isPickedExact &&
      isPackedExact &&
      lines.every((line) => line.isTrackingComplete);
  double get totalRequired =>
      lines.fold(0, (sum, line) => sum + line.requiredQty);
  double get totalPicked => lines.fold(0, (sum, line) => sum + line.pickedQty);
  double get totalPacked => lines.fold(0, (sum, line) => sum + line.packedQty);

  FulfillmentDraft setSource(String? warehouse) => copyWith(
        sourceWarehouse: warehouse,
        sourceLocation: null,
      );

  FulfillmentDraft setSourceLocation(String? location) =>
      copyWith(sourceLocation: location);

  FulfillmentDraft setPickedQty(String salesOrderItem, double qty) {
    return copyWith(
      lines: [
        for (final line in lines)
          line.salesOrderItem == salesOrderItem
              ? line.copyWith(pickedQty: qty)
              : line,
      ],
    );
  }

  FulfillmentDraft setPackedQty(String salesOrderItem, double qty) {
    return copyWith(
      lines: [
        for (final line in lines)
          line.salesOrderItem == salesOrderItem
              ? line.copyWith(packedQty: qty)
              : line,
      ],
    );
  }

  FulfillmentDraft setAllocations(
    String salesOrderItem,
    List<TrackingAllocation> allocations,
  ) {
    return copyWith(
      lines: [
        for (final line in lines)
          line.salesOrderItem == salesOrderItem
              ? line.copyWith(allocations: allocations)
              : line,
      ],
    );
  }

  FulfillmentDraft addPickedItem(String itemCode, double qty) {
    var remaining = qty;
    final updated = <FulfillmentLine>[];
    for (final line in lines) {
      if (line.itemCode != itemCode || remaining <= 0) {
        updated.add(line);
        continue;
      }
      final add =
          remaining <= line.remainingPick ? remaining : line.remainingPick;
      updated.add(line.copyWith(pickedQty: line.pickedQty + add));
      remaining -= add;
    }
    if (remaining > 0) {
      final index = updated.indexWhere((line) => line.itemCode == itemCode);
      if (index != -1) {
        final line = updated[index];
        updated[index] = line.copyWith(pickedQty: line.pickedQty + remaining);
      }
    }
    return copyWith(lines: updated);
  }

  FulfillmentDraft confirmPickedAsPacked() {
    return copyWith(
      lines: [
        for (final line in lines) line.copyWith(packedQty: line.pickedQty),
      ],
    );
  }

  Map<String, dynamic> toPayload() => {
        'sales_order': salesOrder,
        'customer': customer,
        'source_warehouse': sourceWarehouse,
        if (sourceLocation != null) 'source_location': sourceLocation,
        'items': lines.map((line) => line.toPayloadJson()).toList(),
        if (company != null) 'company': company,
      };

  Map<String, dynamic> toJson() => {
        'sales_order': salesOrder,
        'customer': customer,
        'company': company,
        'source_warehouse': sourceWarehouse,
        'source_location': sourceLocation,
        'stage': stage.name,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory FulfillmentDraft.fromJson(Map<String, dynamic> json) {
    return FulfillmentDraft(
      salesOrder: json['sales_order'] as String,
      customer: json['customer'] as String?,
      company: json['company'] as String?,
      sourceWarehouse: json['source_warehouse'] as String?,
      sourceLocation: json['source_location'] as String?,
      stage: FulfillmentStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => FulfillmentStage.pick,
      ),
      lines: (json['lines'] as List? ?? const [])
          .cast<Map>()
          .map((raw) => FulfillmentLine.fromJson(raw.cast<String, dynamic>()))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        salesOrder,
        customer,
        company,
        sourceWarehouse,
        sourceLocation,
        stage,
        lines,
      ];
}

bool _sameQty(double a, double b) => (a - b).abs() < 0.000001;

const _sentinel = Object();

bool _trackingComplete({
  required double qty,
  required bool hasBatchNo,
  required bool hasSerialNo,
  required List<TrackingAllocation> allocations,
}) {
  if (!hasBatchNo && !hasSerialNo) return true;
  if (allocations.isEmpty) return false;
  final total = allocations.fold<double>(0, (sum, a) => sum + a.qty);
  if ((total - qty).abs() > 0.000001) return false;
  for (final allocation in allocations) {
    if (hasBatchNo &&
        (allocation.batchNo == null || allocation.batchNo!.isEmpty)) {
      return false;
    }
    if (hasSerialNo && allocation.serialNos.length != allocation.qty.round()) {
      return false;
    }
  }
  return true;
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes', 'y'}
      .contains(value?.toString().trim().toLowerCase());
}
