import 'package:equatable/equatable.dart';

class WarehouseStockLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double actualQty;
  final double reservedQty;
  final double orderedQty;
  final double projectedQty;
  final String? stockUom;

  const WarehouseStockLine({
    required this.itemCode,
    this.itemName,
    required this.actualQty,
    required this.reservedQty,
    required this.orderedQty,
    required this.projectedQty,
    this.stockUom,
  });

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        actualQty,
        reservedQty,
        orderedQty,
        projectedQty,
        stockUom,
      ];
}
