import 'package:equatable/equatable.dart';

class ItemStock extends Equatable {
  final String warehouse;
  final double actualQty;
  final double reservedQty;
  final double orderedQty;
  final double projectedQty;
  final String? stockUom;

  const ItemStock({
    required this.warehouse,
    required this.actualQty,
    required this.reservedQty,
    required this.orderedQty,
    required this.projectedQty,
    this.stockUom,
  });

  @override
  List<Object?> get props => [
        warehouse,
        actualQty,
        reservedQty,
        orderedQty,
        projectedQty,
        stockUom,
      ];
}
