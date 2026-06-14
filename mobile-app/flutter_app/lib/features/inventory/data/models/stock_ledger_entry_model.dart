import '../../domain/entities/stock_ledger_entry.dart';

class StockLedgerEntryModel {
  final DateTime postingDate;
  final String? postingTime;
  final String voucherType;
  final String voucherNo;
  final String warehouse;
  final double actualQty;
  final double qtyAfterTransaction;
  final double? valuationRate;
  final double? stockValueDifference;

  const StockLedgerEntryModel({
    required this.postingDate,
    this.postingTime,
    required this.voucherType,
    required this.voucherNo,
    required this.warehouse,
    required this.actualQty,
    required this.qtyAfterTransaction,
    this.valuationRate,
    this.stockValueDifference,
  });

  factory StockLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double? asNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final dateStr = json['posting_date'] as String? ?? '1970-01-01';
    final date = DateTime.tryParse(dateStr) ?? DateTime(1970);

    return StockLedgerEntryModel(
      postingDate: date,
      postingTime: json['posting_time'] as String?,
      voucherType: json['voucher_type'] as String? ?? '',
      voucherNo: json['voucher_no'] as String? ?? '',
      warehouse: json['warehouse'] as String? ?? '',
      actualQty: asDouble(json['actual_qty']),
      qtyAfterTransaction: asDouble(json['qty_after_transaction']),
      valuationRate: asNullableDouble(json['valuation_rate']),
      stockValueDifference: asNullableDouble(json['stock_value_difference']),
    );
  }

  StockLedgerEntry toEntity() => StockLedgerEntry(
        postingDate: postingDate,
        postingTime: postingTime,
        voucherType: voucherType,
        voucherNo: voucherNo,
        warehouse: warehouse,
        actualQty: actualQty,
        qtyAfterTransaction: qtyAfterTransaction,
        valuationRate: valuationRate,
        stockValueDifference: stockValueDifference,
      );
}
