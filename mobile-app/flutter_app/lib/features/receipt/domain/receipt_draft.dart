import 'package:equatable/equatable.dart';

class ReceiptLine extends Equatable {
  final String itemCode;
  final String? itemName;
  final double qty;

  const ReceiptLine({
    required this.itemCode,
    required this.qty,
    this.itemName,
  });

  ReceiptLine copyWith({double? qty}) =>
      ReceiptLine(itemCode: itemCode, qty: qty ?? this.qty, itemName: itemName);

  Map<String, dynamic> toJson() => {'item_code': itemCode, 'qty': qty};

  @override
  List<Object?> get props => [itemCode, itemName, qty];
}

/// In-flight receipt — either an ad-hoc Material Receipt (no PO) or a
/// Purchase Receipt against an existing PO.
class ReceiptDraft extends Equatable {
  final String? targetWarehouse;
  final String? againstPo;
  final List<ReceiptLine> lines;
  final String? company;

  const ReceiptDraft({
    this.targetWarehouse,
    this.againstPo,
    this.lines = const [],
    this.company,
  });

  ReceiptDraft copyWith({
    String? targetWarehouse,
    String? againstPo,
    List<ReceiptLine>? lines,
    bool clearAgainstPo = false,
    Object? company = _sentinel,
  }) {
    return ReceiptDraft(
      targetWarehouse: targetWarehouse ?? this.targetWarehouse,
      againstPo: clearAgainstPo ? null : (againstPo ?? this.againstPo),
      lines: lines ?? this.lines,
      company: company == _sentinel ? this.company : company as String?,
    );
  }

  bool get isSubmittable =>
      targetWarehouse != null &&
      lines.isNotEmpty &&
      lines.every((l) => l.qty > 0);

  Map<String, dynamic> toPayload() => {
        'target_warehouse': targetWarehouse,
        if (againstPo != null) 'against_po': againstPo,
        'items': lines.map((l) => l.toJson()).toList(),
        if (company != null) 'company': company,
      };

  @override
  List<Object?> get props => [targetWarehouse, againstPo, lines, company];
}

const _sentinel = Object();
