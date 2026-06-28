import 'package:equatable/equatable.dart';

import '../../tracking/domain/tracking_allocation.dart';

class TransferLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double qty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final List<TrackingAllocation> allocations;

  const TransferLine({
    required this.itemCode,
    required this.qty,
    this.itemName,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.allocations = const [],
  });

  TransferLine copyWith({
    double? qty,
    List<TrackingAllocation>? allocations,
  }) =>
      TransferLine(
        itemCode: itemCode,
        qty: qty ?? this.qty,
        itemName: itemName,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations ?? this.allocations,
      );

  bool get isTrackingComplete => _trackingComplete(
        qty: qty,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations,
      );

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'qty': qty,
        if (allocations.isNotEmpty)
          'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        qty,
        hasBatchNo,
        hasSerialNo,
        allocations,
      ];
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
      lines.every((l) => l.qty > 0 && l.isTrackingComplete);

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
