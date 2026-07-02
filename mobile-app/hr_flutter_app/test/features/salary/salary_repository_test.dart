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

  test('parses salary slip detail with earnings and deductions', () {
    final detail = SalarySlipDetail.fromJson({
      'name': 'SAL-001',
      'start_date': '2026-06-01',
      'end_date': '2026-06-30',
      'gross_pay': 1200,
      'total_deduction': 200,
      'net_pay': 1000,
      'earnings': [
        {'component': 'Basic', 'amount': 1200},
      ],
      'deductions': [
        {'component': 'Tax', 'amount': 200},
      ],
    });

    expect(detail.netPay, 1000);
    expect(detail.earnings.single.component, 'Basic');
    expect(detail.deductions.single.amount, 200);
  });

  test('parses salary slip PDF link payload', () {
    final link = SalarySlipPdfLink.fromJson({
      'name': 'SAL-001',
      'url': 'https://erp.example.com/api/method/download_pdf',
    });

    expect(link.name, 'SAL-001');
    expect(link.url, contains('download_pdf'));
  });
}
