import 'package:equatable/equatable.dart';

class TrackingAllocation extends Equatable {
  final double qty;
  final String? batchNo;
  final String? expiryDate;
  final List<String> serialNos;

  const TrackingAllocation({
    required this.qty,
    this.batchNo,
    this.expiryDate,
    this.serialNos = const [],
  });

  factory TrackingAllocation.fromJson(Map<String, dynamic> json) {
    return TrackingAllocation(
      qty: (json['qty'] as num).toDouble(),
      batchNo: json['batch_no'] as String?,
      expiryDate: json['expiry_date'] as String?,
      serialNos:
          (json['serial_nos'] as List? ?? const []).map((v) => '$v').toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'qty': qty,
        if (batchNo != null && batchNo!.isNotEmpty) 'batch_no': batchNo,
        if (expiryDate != null && expiryDate!.isNotEmpty)
          'expiry_date': expiryDate,
        if (serialNos.isNotEmpty) 'serial_nos': serialNos,
      };

  @override
  List<Object?> get props => [qty, batchNo, expiryDate, serialNos];
}

String trackingSummary(List<TrackingAllocation> allocations) {
  if (allocations.isEmpty) return '';
  final parts = <String>[];
  for (final allocation in allocations) {
    final batch = allocation.batchNo;
    if (batch != null && batch.isNotEmpty) {
      parts.add('Batch $batch');
    }
    if (allocation.expiryDate != null && allocation.expiryDate!.isNotEmpty) {
      parts.add('Exp ${allocation.expiryDate}');
    }
    if (allocation.serialNos.isNotEmpty) {
      final serials = allocation.serialNos.take(3).join(', ');
      final extra = allocation.serialNos.length > 3
          ? ' +${allocation.serialNos.length - 3}'
          : '';
      parts.add('Serial $serials$extra');
    }
  }
  return parts.join(' / ');
}
