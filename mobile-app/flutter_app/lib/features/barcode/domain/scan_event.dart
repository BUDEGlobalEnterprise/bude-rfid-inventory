import 'package:equatable/equatable.dart';

class ScanEvent extends Equatable {
  final String barcode;
  final String? format;
  final DateTime timestamp;

  ScanEvent({
    required this.barcode,
    this.format,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [barcode, format, timestamp];
}
