import 'package:bude_hr/features/attendance/data/attendance_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores pending attendance operations offline', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = AttendanceQueue();

    await queue.enqueue(
      PendingAttendanceOp(
        type: 'IN',
        createdAt: DateTime.parse('2026-07-01T09:00:00'),
      ),
    );

    final rows = await queue.read();
    expect(rows, hasLength(1));
    expect(rows.single.type, 'IN');
  });
}
