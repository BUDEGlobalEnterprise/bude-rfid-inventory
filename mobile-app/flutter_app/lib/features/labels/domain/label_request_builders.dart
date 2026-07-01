import 'package:intl/intl.dart';

import '../../../core/sync/pending_operation.dart';
import '../../inventory/domain/entities/item.dart';
import '../../receipt/domain/receipt_draft.dart';
import 'label_request.dart';

LabelRequest itemLabelRequest(
  Item item, {
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  return LabelRequest(
    kind: LabelKind.item,
    format: format,
    size: size,
    title: item.itemName,
    primaryCode: item.itemCode,
    subtitle: item.description,
    quantity: quantity,
    metadata: {
      if ((item.stockUom ?? '').trim().isNotEmpty) 'UOM': item.stockUom!,
      if ((item.itemGroup ?? '').trim().isNotEmpty) 'Group': item.itemGroup!,
    },
  );
}

LabelRequest binLocationLabelRequest({
  required String locationName,
  String? parentWarehouse,
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  return LabelRequest(
    kind: LabelKind.binLocation,
    format: format,
    size: size,
    title: locationName,
    primaryCode: locationName,
    subtitle: parentWarehouse,
    quantity: quantity,
    metadata: {
      if ((parentWarehouse ?? '').trim().isNotEmpty)
        'Warehouse': parentWarehouse!,
    },
  );
}

int _palletSequence = 0;

String generatePalletId({DateTime? now, int? sequence}) {
  final ts = now ?? DateTime.now();
  final effectiveSequence = sequence ?? _palletSequence++;
  final date = DateFormat('yyyyMMddHHmmss').format(ts.toUtc());
  final suffix = (effectiveSequence % 46656)
      .toRadixString(36)
      .padLeft(3, '0')
      .toUpperCase();
  return 'PAL-$date-$suffix';
}

LabelRequest palletLabelRequest({
  String? palletId,
  String? warehouse,
  String? location,
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  final code = palletId == null || palletId.trim().isEmpty
      ? generatePalletId()
      : palletId;
  return LabelRequest(
    kind: LabelKind.pallet,
    format: format,
    size: size,
    title: 'Pallet',
    primaryCode: code,
    subtitle: location ?? warehouse,
    quantity: quantity,
    metadata: {
      if ((warehouse ?? '').trim().isNotEmpty) 'Warehouse': warehouse!,
      if ((location ?? '').trim().isNotEmpty) 'Location': location!,
    },
  );
}

LabelRequest receiptLabelRequestFromDraft({
  required String opId,
  String? serverRef,
  required ReceiptDraft draft,
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  return receiptLabelRequestFromPayload(
    opId: opId,
    serverRef: serverRef,
    payload: draft.toPayload(),
    format: format,
    size: size,
    quantity: quantity,
  );
}

LabelRequest receiptLabelRequestFromOperation(
  PendingOperation op, {
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  return receiptLabelRequestFromPayload(
    opId: op.id,
    serverRef: op.serverRef,
    payload: op.payload,
    format: format,
    size: size,
    quantity: quantity,
  );
}

LabelRequest receiptLabelRequestFromPayload({
  required String opId,
  String? serverRef,
  required Map<String, dynamic> payload,
  LabelFormat format = LabelFormat.pdf,
  LabelSize size = LabelSize.medium75x50,
  int quantity = 1,
}) {
  final items = payload['items'] is List ? payload['items'] as List : const [];
  final lineCount = items.length;
  final totalQty = items.fold<double>(0, (sum, raw) {
    if (raw is! Map) return sum;
    final qty = raw['qty'];
    return sum + (qty is num ? qty.toDouble() : 0);
  });
  final targetWarehouse = _string(payload['target_warehouse']);
  final targetLocation = _string(payload['target_location']);
  final againstPo = _string(payload['against_po']);
  final company = _string(payload['company']);
  final code = _firstNonEmpty([serverRef, opId]);

  return LabelRequest(
    kind: LabelKind.receipt,
    format: format,
    size: size,
    title: 'Goods receipt',
    primaryCode: code,
    subtitle: targetLocation.isEmpty ? targetWarehouse : targetLocation,
    quantity: quantity,
    receiptOpId: opId,
    receiptServerRef: serverRef,
    receiptPayload: {
      'op_id': opId,
      if ((serverRef ?? '').trim().isNotEmpty) 'server_ref': serverRef,
      if (targetWarehouse.isNotEmpty) 'target_warehouse': targetWarehouse,
      if (targetLocation.isNotEmpty) 'target_location': targetLocation,
      if (againstPo.isNotEmpty) 'against_po': againstPo,
      'line_count': lineCount,
      'total_qty': totalQty,
    },
    metadata: {
      'Op': opId,
      if ((serverRef ?? '').trim().isNotEmpty) 'Server ref': serverRef!,
      if (targetWarehouse.isNotEmpty) 'Target': targetWarehouse,
      if (targetLocation.isNotEmpty) 'Location': targetLocation,
      if (againstPo.isNotEmpty) 'PO': againstPo,
      'Lines': '$lineCount',
      'Qty': _formatQty(totalQty),
      if (company.isNotEmpty) 'Company': company,
    },
  );
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return 'RECEIPT';
}

String _string(Object? value) => value?.toString().trim() ?? '';

String _formatQty(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
