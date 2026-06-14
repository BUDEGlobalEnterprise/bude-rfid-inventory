import '../../domain/entities/warehouse_stock_line.dart';

class WarehouseStockLineModel {
  final String itemCode;
  final String? itemName;
  final double actualQty;
  final double reservedQty;
  final double orderedQty;
  final double projectedQty;
  final String? stockUom;

  const WarehouseStockLineModel({
    required this.itemCode,
    this.itemName,
    required this.actualQty,
    required this.reservedQty,
    required this.orderedQty,
    required this.projectedQty,
    this.stockUom,
  });

  factory WarehouseStockLineModel.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return WarehouseStockLineModel(
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String?,
      actualQty: asDouble(json['actual_qty']),
      reservedQty: asDouble(json['reserved_qty']),
      orderedQty: asDouble(json['ordered_qty']),
      projectedQty: asDouble(json['projected_qty']),
      stockUom: json['stock_uom'] as String?,
    );
  }

  WarehouseStockLine toEntity() => WarehouseStockLine(
        itemCode: itemCode,
        itemName: itemName,
        actualQty: actualQty,
        reservedQty: reservedQty,
        orderedQty: orderedQty,
        projectedQty: projectedQty,
        stockUom: stockUom,
      );
}
