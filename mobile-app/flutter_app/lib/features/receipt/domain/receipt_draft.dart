import 'package:equatable/equatable.dart';

import '../../tracking/domain/tracking_allocation.dart';

class ReceiptLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double qty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final List<TrackingAllocation> allocations;

  const ReceiptLine({
    required this.itemCode,
    required this.qty,
    this.itemName,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.allocations = const [],
  });

  ReceiptLine copyWith({
    double? qty,
    List<TrackingAllocation>? allocations,
  }) =>
      ReceiptLine(
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
        allowExpiryMissing: true,
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

/// In-flight receipt — either an ad-hoc Material Receipt (no PO) or a
/// Purchase Receipt against an existing PO.
class ReceiptDraft extends Equatable {
  final String? targetWarehouse;
  final String? targetLocation;
  final String? againstPo;
  final String? todoName;
  final List<ReceiptLine> lines;
  final String? company;

  const ReceiptDraft({
    this.targetWarehouse,
    this.targetLocation,
    this.againstPo,
    this.todoName,
    this.lines = const [],
    this.company,
  });

  ReceiptDraft copyWith({
    Object? targetWarehouse = _sentinel,
    Object? targetLocation = _sentinel,
    String? againstPo,
    Object? todoName = _sentinel,
    List<ReceiptLine>? lines,
    bool clearAgainstPo = false,
    Object? company = _sentinel,
  }) {
    return ReceiptDraft(
      targetWarehouse: targetWarehouse == _sentinel
          ? this.targetWarehouse
          : targetWarehouse as String?,
      targetLocation: targetLocation == _sentinel
          ? this.targetLocation
          : targetLocation as String?,
      againstPo: clearAgainstPo ? null : (againstPo ?? this.againstPo),
      todoName: todoName == _sentinel ? this.todoName : todoName as String?,
      lines: lines ?? this.lines,
      company: company == _sentinel ? this.company : company as String?,
    );
  }

  bool get isSubmittable =>
      targetWarehouse != null &&
      lines.isNotEmpty &&
      lines.every((l) => l.qty > 0 && l.isTrackingComplete);

  Map<String, dynamic> toPayload() => {
        'target_warehouse': targetWarehouse,
        if (targetLocation != null) 'target_location': targetLocation,
        if (againstPo != null) 'against_po': againstPo,
        if (todoName != null) 'todo_name': todoName,
        'items': lines.map((l) => l.toJson()).toList(),
        if (company != null) 'company': company,
      };

  @override
  List<Object?> get props => [
        targetWarehouse,
        targetLocation,
        againstPo,
        todoName,
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
  required bool allowExpiryMissing,
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
    if (hasBatchNo &&
        !allowExpiryMissing &&
        (allocation.expiryDate == null || allocation.expiryDate!.isEmpty)) {
      return false;
    }
    if (hasSerialNo && allocation.serialNos.length != allocation.qty.round()) {
      return false;
    }
  }
  return true;
}
