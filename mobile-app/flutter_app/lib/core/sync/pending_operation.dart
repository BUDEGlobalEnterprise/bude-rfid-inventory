import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Status of a queued operation in its lifecycle.
enum OpStatus { pendingApproval, pending, inflight, succeeded, failed }

/// A serialized write operation waiting to be sent to ERPNext.
///
/// Persisted as JSON in a Hive `Box<String>` keyed by [id]. Stored
/// as JSON (not via a Hive `TypeAdapter`) to skip code generation in
/// Phase 3 — switch to a typed adapter later if the box grows large.
class PendingOperation extends Equatable {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final OpStatus status;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final String? serverRef;
  final DateTime? nextRetryAt;

  const PendingOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.serverRef,
    this.nextRetryAt,
  });

  PendingOperation copyWith({
    OpStatus? status,
    int? attempts,
    String? lastError,
    String? serverRef,
    DateTime? nextRetryAt,
    bool clearError = false,
    bool clearNextRetry = false,
  }) {
    return PendingOperation(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearError ? null : (lastError ?? this.lastError),
      serverRef: serverRef ?? this.serverRef,
      nextRetryAt: clearNextRetry ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
        'serverRef': serverRef,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
      };

  static PendingOperation fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: (json['payload'] as Map).cast<String, dynamic>(),
      status: OpStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OpStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as int?) ?? 0,
      lastError: json['lastError'] as String?,
      serverRef: json['serverRef'] as String?,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.parse(json['nextRetryAt'] as String)
          : null,
    );
  }

  String encode() => jsonEncode(toJson());

  static PendingOperation decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
        id,
        type,
        payload,
        status,
        createdAt,
        attempts,
        lastError,
        serverRef,
        nextRetryAt,
      ];
}
