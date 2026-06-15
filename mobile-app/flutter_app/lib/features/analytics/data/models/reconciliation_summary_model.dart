import '../../domain/entities/reconciliation_summary.dart';

class VarianceLineModel {
  final String itemCode;
  final String? itemName;
  final double countedQty;
  final double expectedQty;
  final double variance;
  final String? warehouse;

  const VarianceLineModel({
    required this.itemCode,
    this.itemName,
    required this.countedQty,
    required this.expectedQty,
    required this.variance,
    this.warehouse,
  });

  factory VarianceLineModel.fromJson(Map<String, dynamic> json) {
    return VarianceLineModel(
      itemCode: json['item_code'] as String,
      itemName: json['item_name'] as String?,
      countedQty: _asDouble(json['counted_qty']),
      expectedQty: _asDouble(json['expected_qty']),
      variance: _asDouble(json['variance']),
      warehouse: json['warehouse'] as String?,
    );
  }

  VarianceLine toEntity() => VarianceLine(
        itemCode: itemCode,
        itemName: itemName,
        countedQty: countedQty,
        expectedQty: expectedQty,
        variance: variance,
        warehouse: warehouse,
      );

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class ReconciliationSummaryModel {
  final String name;
  final DateTime postingDate;
  final String? warehouse;
  final List<VarianceLineModel> items;

  const ReconciliationSummaryModel({
    required this.name,
    required this.postingDate,
    this.warehouse,
    required this.items,
  });

  factory ReconciliationSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return ReconciliationSummaryModel(
      name: json['name'] as String,
      postingDate: DateTime.parse(json['posting_date'] as String),
      warehouse: json['warehouse'] as String?,
      items: rawItems.map(VarianceLineModel.fromJson).toList(),
    );
  }

  ReconciliationSummary toEntity() => ReconciliationSummary(
        name: name,
        postingDate: postingDate,
        warehouse: warehouse,
        items: items.map((m) => m.toEntity()).toList(),
      );
}
