import '../../domain/entities/stock_aging_row.dart';

class StockAgingRowModel {
  final String itemCode;
  final String? itemName;
  final double actualQty;
  final int? daysIdle;
  final DateTime? lastMovementDate;

  const StockAgingRowModel({
    required this.itemCode,
    this.itemName,
    required this.actualQty,
    this.daysIdle,
    this.lastMovementDate,
  });

  factory StockAgingRowModel.fromJson(Map<String, dynamic> json) {
    return StockAgingRowModel(
      itemCode: json['item_code'] as String,
      itemName: json['item_name'] as String?,
      actualQty: _asDouble(json['actual_qty']),
      daysIdle: _asNullableInt(json['days_idle']),
      lastMovementDate: _asNullableDate(json['last_movement_date']),
    );
  }

  StockAgingRow toEntity() => StockAgingRow(
        itemCode: itemCode,
        itemName: itemName,
        actualQty: actualQty,
        daysIdle: daysIdle,
        lastMovementDate: lastMovementDate,
      );

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static DateTime? _asNullableDate(dynamic v) {
    if (v == null || v == '') return null;
    return DateTime.tryParse(v.toString());
  }
}
