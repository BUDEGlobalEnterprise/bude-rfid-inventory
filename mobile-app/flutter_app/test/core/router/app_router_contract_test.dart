import 'package:bude_inventory/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public routes', () {
    test('only login and settings are public after tenant setup', () {
      expect(isPublicRoute('/login'), isTrue);
      expect(isPublicRoute('/settings'), isTrue);
      expect(isPublicRoute('/'), isFalse);
      expect(isPublicRoute('/lookup'), isFalse);
      expect(isPublicRoute('/sync'), isFalse);
    });
  });

  group('manager-only locations', () {
    test('covers release-critical manager routes', () {
      expect(isManagerOnlyLocation('/masters'), isTrue);
      expect(isManagerOnlyLocation('/masters/item'), isTrue);
      expect(isManagerOnlyLocation('/warehouse/Main%20Stores'), isTrue);
      expect(isManagerOnlyLocation('/analytics'), isTrue);
      expect(isManagerOnlyLocation('/reports'), isTrue);
    });

    test('leaves operator routes unblocked', () {
      expect(isManagerOnlyLocation('/'), isFalse);
      expect(isManagerOnlyLocation('/lookup'), isFalse);
      expect(isManagerOnlyLocation('/scan-session'), isFalse);
      expect(isManagerOnlyLocation('/sync'), isFalse);
      expect(isManagerOnlyLocation('/settings'), isFalse);
    });
  });

  group('reconciliation approval route contract', () {
    test('accepts a non-empty operation id', () {
      expect(reconciliationApprovalOpIdFromExtra('op-123'), 'op-123');
      expect(reconciliationApprovalOpIdFromExtra('  op-123  '), 'op-123');
    });

    test('rejects missing or malformed extras without throwing', () {
      expect(reconciliationApprovalOpIdFromExtra(null), isNull);
      expect(reconciliationApprovalOpIdFromExtra(''), isNull);
      expect(reconciliationApprovalOpIdFromExtra(42), isNull);
      expect(reconciliationApprovalOpIdFromExtra({'op': 'op-123'}), isNull);
    });
  });
}
