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

  TransferLine copyWith({double? qty}) =>
      TransferLine(itemCode: itemCode, qty: qty ?? this.qty, itemName: itemName);

  Map<String, dynamic> toJson() => {'item_code': itemCode, 'qty': qty};

  @override
  List<Object?> get props => [itemCode, itemName, qty];
}

/// In-flight draft assembled in the TransferScreen, then handed to the sync
/// queue via SubmitTransferUseCase.
class TransferDraft extends Equatable {
  final String? sourceWarehouse;
  final String? targetWarehouse;
  final List<TransferLine> lines;

  const TransferDraft({
    this.sourceWarehouse,
    this.targetWarehouse,
    this.lines = const [],
  });

  TransferDraft copyWith({
    String? sourceWarehouse,
    String? targetWarehouse,
    List<TransferLine>? lines,
  }) {
    return TransferDraft(
      sourceWarehouse: sourceWarehouse ?? this.sourceWarehouse,
      targetWarehouse: targetWarehouse ?? this.targetWarehouse,
      lines: lines ?? this.lines,
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
        'items': lines.map((l) => l.toJson()).toList(),
      };

  @override
  List<Object?> get props => [sourceWarehouse, targetWarehouse, lines];
}
