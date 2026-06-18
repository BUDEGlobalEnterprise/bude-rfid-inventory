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
  final String? company;

  const ReconciliationDraft({
    this.warehouse,
    this.lines = const [],
    this.company,
  });

  ReconciliationDraft copyWith({
    String? warehouse,
    List<CountLine>? lines,
    Object? company = _sentinel,
  }) {
    return ReconciliationDraft(
      warehouse: warehouse ?? this.warehouse,
      lines: lines ?? this.lines,
      company: company == _sentinel ? this.company : company as String?,
    );
  }

  /// Reconciliation accepts 0 (item is gone) but rejects negatives.
  bool get isSubmittable =>
      warehouse != null &&
      lines.isNotEmpty &&
      lines.every((l) => l.countedQty >= 0);

  double get totalVariance => lines.fold(
        0.0,
        (s, l) => s + (l.variance?.abs() ?? 0.0),
      );

  Map<String, dynamic> toPayload() => {
        'warehouse': warehouse,
        'counts': lines.map((l) => l.toJson()).toList(),
        if (company != null) 'company': company,
      };

  @override
  List<Object?> get props => [warehouse, lines, company];
}

const _sentinel = Object();
