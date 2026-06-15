import 'package:equatable/equatable.dart';

class DayBucket extends Equatable {
  final DateTime date;
  final int transferCount;
  final int receiptCount;
  final int reconcileCount;
  final int failedCount;

  const DayBucket({
    required this.date,
    this.transferCount = 0,
    this.receiptCount = 0,
    this.reconcileCount = 0,
    this.failedCount = 0,
  });

  int get totalCount => transferCount + receiptCount + reconcileCount;

  @override
  List<Object?> get props =>
      [date, transferCount, receiptCount, reconcileCount, failedCount];
}

class ThroughputData extends Equatable {
  final List<DayBucket> buckets;
  final int totalOps;
  final double successRate;
  final DateTime? mostActiveDay;

  const ThroughputData({
    required this.buckets,
    required this.totalOps,
    required this.successRate,
    this.mostActiveDay,
  });

  @override
  List<Object?> get props => [buckets, totalOps, successRate, mostActiveDay];
}
