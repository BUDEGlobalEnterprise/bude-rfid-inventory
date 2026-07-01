import 'package:bude_hr/features/salary/data/salary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses salary slip summary payload', () {
    final slip = SalarySlipSummary.fromJson({
      'name': 'SAL-001',
      'start_date': '2026-06-01',
      'end_date': '2026-06-30',
      'net_pay': 1000,
    });

    expect(slip.name, 'SAL-001');
    expect(slip.netPay, 1000);
  });
}
