/// Operation kinds that can be queued while offline. Stored by `name` so the
/// on-disk JSON stays stable if enum ordering changes.
enum PendingOperationType {
  attendanceCheckIn,
  expenseDraft;

  static PendingOperationType fromName(String value) {
    return PendingOperationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PendingOperationType.attendanceCheckIn,
    );
  }
}

/// A single unit of work waiting to sync. `payload` holds the type-specific
/// fields the owning repository needs to replay the request.
class PendingHrOperation {
  final String id;
  final PendingOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingHrOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  /// A short human-readable label for the pending-queue list.
  String get label => switch (type) {
        PendingOperationType.attendanceCheckIn =>
          'Attendance ${payload['type'] ?? ''}'.trim(),
        PendingOperationType.expenseDraft =>
          'Expense ${payload['expense_type'] ?? ''} ${payload['amount'] ?? ''}'
              .trim(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingHrOperation.fromJson(Map json) {
    return PendingHrOperation(
      id: json['id'] as String,
      type: PendingOperationType.fromName(json['type'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
