import 'package:equatable/equatable.dart';

class CountLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double countedQty;

  /// ERPNext-reported on-hand at time of count, if pre-fetched. Display-only.
  final double? expectedQty;

  const CountLine({
    required this.itemCode,
    required this.countedQty,
    this.itemName,
    this.expectedQty,
  });

  CountLine copyWith({double? countedQty, double? expectedQty}) => CountLine(
        itemCode: itemCode,
        countedQty: countedQty ?? this.countedQty,
        itemName: itemName,
        expectedQty: expectedQty ?? this.expectedQty,
      );

  double? get variance =>
      expectedQty == null ? null : countedQty - expectedQty!;

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'qty': countedQty,
      };

  @override
  List<Object?> get props => [itemCode, itemName, countedQty, expectedQty];
}

class ReconciliationDraft extends Equatable {
  final String? warehouse;
  final List<CountLine> lines;

  const ReconciliationDraft({this.warehouse, this.lines = const []});

  ReconciliationDraft copyWith({
    String? warehouse,
    List<CountLine>? lines,
  }) {
    return ReconciliationDraft(
      warehouse: warehouse ?? this.warehouse,
      lines: lines ?? this.lines,
    );
  }

  /// Reconciliation accepts 0 (item is gone) but rejects negatives.
  bool get isSubmittable =>
      warehouse != null &&
      lines.isNotEmpty &&
      lines.every((l) => l.countedQty >= 0);

  Map<String, dynamic> toPayload() => {
        'warehouse': warehouse,
        'counts': lines.map((l) => l.toJson()).toList(),
      };

  @override
  List<Object?> get props => [warehouse, lines];
}
