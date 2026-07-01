import 'package:bude_hr/features/expenses/data/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses expense claim summary payload', () {
    final claim = ExpenseClaimSummary.fromJson({
      'name': 'EXP-001',
      'status': 'Draft',
      'total_claimed_amount': 125,
    });

    expect(claim.name, 'EXP-001');
    expect(claim.totalClaimedAmount, 125);
  });
}
