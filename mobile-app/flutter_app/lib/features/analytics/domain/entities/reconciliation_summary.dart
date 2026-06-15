import 'package:equatable/equatable.dart';

class VarianceLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double countedQty;
  final double expectedQty;
  final double variance;
  final String? warehouse;

  const VarianceLine({
    required this.itemCode,
    this.itemName,
    required this.countedQty,
    required this.expectedQty,
    required this.variance,
    this.warehouse,
  });

  @override
  List<Object?> get props =>
      [itemCode, itemName, countedQty, expectedQty, variance, warehouse];
}

class ReconciliationSummary extends Equatable {
  final String name;
  final DateTime postingDate;
  final String? warehouse;
  final List<VarianceLine> items;

  const ReconciliationSummary({
    required this.name,
    required this.postingDate,
    this.warehouse,
    required this.items,
  });

  int get surplusCount => items.where((l) => l.variance > 0).length;
  int get deficitCount => items.where((l) => l.variance < 0).length;

  @override
  List<Object?> get props => [name, postingDate, warehouse, items];
}
