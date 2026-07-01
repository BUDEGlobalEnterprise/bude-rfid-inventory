import 'package:equatable/equatable.dart';

import '../../inventory/domain/entities/item.dart';

/// A shortage/damage flag an operator can attach to a resolved scanned item
/// during transfer/receipt/reconciliation scan sessions.
enum ScanExceptionType { shortage, damage }

class ScannedItem extends Equatable {
  final String barcode;

  /// Null means the barcode never resolved to a known item — kept in the
  /// scan-session list instead of being silently discarded so the operator
  /// can see and act on it (dismiss it, or proceed and have it logged).
  final Item? item;
  final double qty;
  final ScanExceptionType? exceptionType;
  final String? exceptionNote;

  const ScannedItem({
    required this.barcode,
    required this.item,
    this.qty = 1.0,
    this.exceptionType,
    this.exceptionNote,
  });

  bool get isUnresolved => item == null;

  ScannedItem copyWith({
    double? qty,
    Object? exceptionType = _sentinel,
    Object? exceptionNote = _sentinel,
  }) =>
      ScannedItem(
        barcode: barcode,
        item: item,
        qty: qty ?? this.qty,
        exceptionType: exceptionType == _sentinel
            ? this.exceptionType
            : exceptionType as ScanExceptionType?,
        exceptionNote:
            exceptionNote == _sentinel ? this.exceptionNote : exceptionNote as String?,
      );

  @override
  List<Object?> get props => [barcode, item, qty, exceptionType, exceptionNote];
}

const _sentinel = Object();
