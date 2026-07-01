import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final attendanceQueueProvider = Provider<AttendanceQueue>((ref) {
  return AttendanceQueue();
});

class AttendanceQueue {
  static const _key = 'pending_attendance_ops';

  Future<List<PendingAttendanceOp>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((item) => PendingAttendanceOp.fromJson(jsonDecode(item) as Map))
        .toList();
  }

  Future<void> enqueue(PendingAttendanceOp op) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    await prefs.setStringList(_key, [
      ...current,
      jsonEncode(op.toJson()),
    ]);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class PendingAttendanceOp {
  final String type;
  final DateTime createdAt;

  const PendingAttendanceOp({required this.type, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'type': type,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingAttendanceOp.fromJson(Map json) {
    return PendingAttendanceOp(
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
