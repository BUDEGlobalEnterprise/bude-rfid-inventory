import 'package:equatable/equatable.dart';

import '../../tracking/domain/tracking_allocation.dart';

class CountLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double countedQty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final List<TrackingAllocation> allocations;

  /// ERPNext-reported on-hand at time of count, if pre-fetched. Display-only.
  final double? expectedQty;

  const CountLine({
    required this.itemCode,
    required this.countedQty,
    this.itemName,
    this.expectedQty,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.allocations = const [],
  });

  CountLine copyWith({
    double? countedQty,
    double? expectedQty,
    List<TrackingAllocation>? allocations,
  }) =>
      CountLine(
        itemCode: itemCode,
        countedQty: countedQty ?? this.countedQty,
        itemName: itemName,
        expectedQty: expectedQty ?? this.expectedQty,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations ?? this.allocations,
      );

  double? get variance =>
      expectedQty == null ? null : countedQty - expectedQty!;

  bool get isTrackingComplete => _trackingComplete(
        qty: countedQty,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations,
      );

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'qty': countedQty,
        if (allocations.isNotEmpty)
          'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        countedQty,
        expectedQty,
        hasBatchNo,
        hasSerialNo,
        allocations,
      ];
}

class ReconciliationDraft extends Equatable {
  final String? warehouse;
  final String? location;
  final List<CountLine> lines;
  final String? company;

  const ReconciliationDraft({
    this.warehouse,
    this.location,
    this.lines = const [],
    this.company,
  });

  ReconciliationDraft copyWith({
    Object? warehouse = _sentinel,
    Object? location = _sentinel,
    List<CountLine>? lines,
    Object? company = _sentinel,
  }) {
    return ReconciliationDraft(
      warehouse: warehouse == _sentinel ? this.warehouse : warehouse as String?,
      location: location == _sentinel ? this.location : location as String?,
      lines: lines ?? this.lines,
      company: company == _sentinel ? this.company : company as String?,
    );
  }

  /// Reconciliation accepts 0 (item is gone) but rejects negatives.
  bool get isSubmittable =>
      warehouse != null &&
      lines.isNotEmpty &&
      lines.every((l) => l.countedQty >= 0 && l.isTrackingComplete);

  double get totalVariance => lines.fold(
        0.0,
        (s, l) => s + (l.variance?.abs() ?? 0.0),
      );

  Map<String, dynamic> toPayload() => {
        'warehouse': warehouse,
        if (location != null) 'location': location,
        'counts': lines.map((l) => l.toJson()).toList(),
        if (company != null) 'company': company,
      };

  @override
  List<Object?> get props => [warehouse, location, lines, company];
}

const _sentinel = Object();

bool _trackingComplete({
  required double qty,
  required bool hasBatchNo,
  required bool hasSerialNo,
  required List<TrackingAllocation> allocations,
}) {
  if (!hasBatchNo && !hasSerialNo) return true;
  if (allocations.isEmpty) return false;
  final total = allocations.fold<double>(0, (sum, a) => sum + a.qty);
  if ((total - qty).abs() > 0.000001) return false;
  for (final allocation in allocations) {
    if (hasBatchNo &&
        (allocation.batchNo == null || allocation.batchNo!.isEmpty)) {
      return false;
    }
    if (hasSerialNo && allocation.serialNos.length != allocation.qty.round()) {
      return false;
    }
  }
  return true;
}
