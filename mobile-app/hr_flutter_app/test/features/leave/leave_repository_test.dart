import 'package:bude_hr/features/leave/data/leave_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses leave balance payload', () {
    final balance = LeaveBalance.fromJson({
      'leave_type': 'Annual Leave',
      'allocated': 20,
      'used': 3,
      'available': 17,
    });

    expect(balance.leaveType, 'Annual Leave');
    expect(balance.available, 17);
  });
}
