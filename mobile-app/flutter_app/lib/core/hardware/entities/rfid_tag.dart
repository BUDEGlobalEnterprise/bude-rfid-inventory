import 'package:equatable/equatable.dart';

/// A single RFID tag read. Vendor adapters are expected to normalize their
/// proprietary tag formats into this shape.
class RfidTag extends Equatable {
  /// EPC (Electronic Product Code) — the primary identifier.
  final String epc;

  /// Optional Tag Identifier — vendor-assigned, immutable per tag.
  final String? tid;

  /// Optional user memory bank read.
  final String? userMemory;

  /// Received Signal Strength Indicator, in dBm. Negative values; closer to 0
  /// means stronger signal. Null if the adapter doesn't report it.
  final int? rssi;

  /// Antenna port that read the tag (for multi-antenna fixed readers).
  final int? antenna;

  final DateTime timestamp;

  RfidTag({
    required this.epc,
    this.tid,
    this.userMemory,
    this.rssi,
    this.antenna,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [epc, tid, userMemory, rssi, antenna, timestamp];
}
