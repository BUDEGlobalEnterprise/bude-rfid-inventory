import 'package:equatable/equatable.dart';

class TransferLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double qty;

  const TransferLine({
    required this.itemCode,
    required this.qty,
    this.itemName,
  });

  TransferLine copyWith({double? qty}) => TransferLine(
        itemCode: itemCode,
        qty: qty ?? this.qty,
        itemName: itemName,
      );

  Map<String, dynamic> toJson() => {'item_code': itemCode, 'qty': qty};

  @override
  List<Object?> get props => [itemCode, itemName, qty];
}

/// In-flight draft assembled in the TransferScreen, then handed to the sync
/// queue via SubmitTransferUseCase.
class TransferDraft extends Equatable {
  final String? sourceWarehouse;
  final String? targetWarehouse;
  final String? sourceLocation;
  final String? targetLocation;
  final List<TransferLine> lines;
  final String? company;

  const TransferDraft({
    this.sourceWarehouse,
    this.targetWarehouse,
    this.sourceLocation,
    this.targetLocation,
    this.lines = const [],
    this.company,
  });

  TransferDraft copyWith({
    Object? sourceWarehouse = _sentinel,
    Object? targetWarehouse = _sentinel,
    Object? sourceLocation = _sentinel,
    Object? targetLocation = _sentinel,
    List<TransferLine>? lines,
    Object? company = _sentinel,
  }) {
    return TransferDraft(
      sourceWarehouse: sourceWarehouse == _sentinel
          ? this.sourceWarehouse
          : sourceWarehouse as String?,
      targetWarehouse: targetWarehouse == _sentinel
          ? this.targetWarehouse
          : targetWarehouse as String?,
      sourceLocation: sourceLocation == _sentinel
          ? this.sourceLocation
          : sourceLocation as String?,
      targetLocation: targetLocation == _sentinel
          ? this.targetLocation
          : targetLocation as String?,
      lines: lines ?? this.lines,
      company: company == _sentinel ? this.company : company as String?,
    );
  }

  bool get isSubmittable =>
      sourceWarehouse != null &&
      targetWarehouse != null &&
      sourceWarehouse != targetWarehouse &&
      lines.isNotEmpty &&
      lines.every((l) => l.qty > 0);

  Map<String, dynamic> toPayload() => {
        'source_warehouse': sourceWarehouse,
        'target_warehouse': targetWarehouse,
        if (sourceLocation != null) 'source_location': sourceLocation,
        if (targetLocation != null) 'target_location': targetLocation,
        'items': lines.map((l) => l.toJson()).toList(),
        if (company != null) 'company': company,
      };

  @override
  List<Object?> get props => [
        sourceWarehouse,
        targetWarehouse,
        sourceLocation,
        targetLocation,
        lines,
        company,
      ];
}

const _sentinel = Object();
