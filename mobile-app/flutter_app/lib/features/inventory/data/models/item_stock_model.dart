import '../../domain/entities/item_stock.dart';

class ItemStockModel {
  final String warehouse;
  final double actualQty;
  final double reservedQty;
  final double orderedQty;
  final double projectedQty;
  final String? stockUom;

  const ItemStockModel({
    required this.warehouse,
    required this.actualQty,
    required this.reservedQty,
    required this.orderedQty,
    required this.projectedQty,
    this.stockUom,
  });

  factory ItemStockModel.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return ItemStockModel(
      warehouse: json['warehouse'] as String,
      actualQty: asDouble(json['actual_qty']),
      reservedQty: asDouble(json['reserved_qty']),
      orderedQty: asDouble(json['ordered_qty']),
      projectedQty: asDouble(json['projected_qty']),
      stockUom: json['stock_uom'] as String?,
    );
  }

  ItemStock toEntity() => ItemStock(
        warehouse: warehouse,
        actualQty: actualQty,
        reservedQty: reservedQty,
        orderedQty: orderedQty,
        projectedQty: projectedQty,
        stockUom: stockUom,
      );
}
