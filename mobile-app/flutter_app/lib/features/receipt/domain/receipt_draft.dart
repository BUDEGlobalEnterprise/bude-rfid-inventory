import 'package:equatable/equatable.dart';

import '../../tracking/domain/tracking_allocation.dart';

class ReceiptLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double qty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final List<TrackingAllocation> allocations;

  /// Goods received but not accepted (damaged/short). Only meaningful for
  /// PO-backed receipts — mirrors ERPNext's standard Purchase Receipt Item
  /// `rejected_qty` / `rejected_warehouse` fields.
  final double rejectedQty;
  final String? rejectedWarehouse;

  /// Free-text exception note. Sent for both PO and ad-hoc receipts — folds
  /// into the submitted document's `remarks` field server-side.
  final String? damageNote;

  const ReceiptLine({
    required this.itemCode,
    required this.qty,
    this.itemName,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.allocations = const [],
    this.rejectedQty = 0,
    this.rejectedWarehouse,
    this.damageNote,
  });

  ReceiptLine copyWith({
    double? qty,
    List<TrackingAllocation>? allocations,
    double? rejectedQty,
    Object? rejectedWarehouse = _sentinel,
    Object? damageNote = _sentinel,
  }) =>
      ReceiptLine(
        itemCode: itemCode,
        qty: qty ?? this.qty,
        itemName: itemName,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations ?? this.allocations,
        rejectedQty: rejectedQty ?? this.rejectedQty,
        rejectedWarehouse: rejectedWarehouse == _sentinel
            ? this.rejectedWarehouse
            : rejectedWarehouse as String?,
        damageNote:
            damageNote == _sentinel ? this.damageNote : damageNote as String?,
      );

  bool get isTrackingComplete => _trackingComplete(
        qty: qty,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        allocations: allocations,
        allowExpiryMissing: true,
      );

  bool get hasException =>
      rejectedQty > 0 || (damageNote != null && damageNote!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'qty': qty,
        if (allocations.isNotEmpty)
          'allocations': allocations.map((a) => a.toJson()).toList(),
        if (rejectedQty > 0) 'rejected_qty': rejectedQty,
        if (rejectedWarehouse != null) 'rejected_warehouse': rejectedWarehouse,
        if (damageNote != null && damageNote!.trim().isNotEmpty)
          'damage_note': damageNote!.trim(),
      };

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        qty,
        hasBatchNo,
        hasSerialNo,
        allocations,
        rejectedQty,
        rejectedWarehouse,
        damageNote,
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

  /// Raw barcodes scanned but never resolved to an item, kept so an
  /// operator's "proceed anyway" isn't silently lost — noted in the
  /// submitted document's `remarks` server-side.
  final List<String> unresolvedScans;

  const ReceiptDraft({
    this.targetWarehouse,
    this.targetLocation,
    this.againstPo,
    this.todoName,
    this.lines = const [],
    this.company,
    this.unresolvedScans = const [],
  });

  ReceiptDraft copyWith({
    Object? targetWarehouse = _sentinel,
    Object? targetLocation = _sentinel,
    String? againstPo,
    Object? todoName = _sentinel,
    List<ReceiptLine>? lines,
    bool clearAgainstPo = false,
    Object? company = _sentinel,
    List<String>? unresolvedScans,
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
      unresolvedScans: unresolvedScans ?? this.unresolvedScans,
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
        if (unresolvedScans.isNotEmpty) 'unresolved_scans': unresolvedScans,
      };

  @override
  List<Object?> get props => [
        targetWarehouse,
        targetLocation,
        againstPo,
        todoName,
        lines,
        company,
        unresolvedScans,
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
