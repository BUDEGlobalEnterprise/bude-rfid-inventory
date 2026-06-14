import 'package:equatable/equatable.dart';

class StockLedgerEntry extends Equatable {
  final DateTime postingDate;
  final String? postingTime;
  final String voucherType;
  final String voucherNo;
  final String warehouse;
  final double actualQty;
  final double qtyAfterTransaction;
  final double? valuationRate;
  final double? stockValueDifference;

  const StockLedgerEntry({
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

  @override
  List<Object?> get props => [
        postingDate,
        postingTime,
        voucherType,
        voucherNo,
        warehouse,
        actualQty,
        qtyAfterTransaction,
        valuationRate,
        stockValueDifference,
      ];
}
