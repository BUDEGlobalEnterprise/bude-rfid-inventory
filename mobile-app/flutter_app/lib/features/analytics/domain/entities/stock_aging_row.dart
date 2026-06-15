import 'package:equatable/equatable.dart';

class StockAgingRow extends Equatable {
  final String itemCode;
  final String? itemName;
  final double actualQty;
  final int? daysIdle;
  final DateTime? lastMovementDate;

  const StockAgingRow({
    required this.itemCode,
    this.itemName,
    required this.actualQty,
    this.daysIdle,
    this.lastMovementDate,
  });

  @override
  List<Object?> get props =>
      [itemCode, itemName, actualQty, daysIdle, lastMovementDate];
}
