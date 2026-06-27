import 'package:bude_inventory/core/network/auth_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('treats 401 and 403 as unauthorized', () {
    expect(isUnauthorizedStatus(401), isTrue);
    expect(isUnauthorizedStatus(403), isTrue);
  });

  test('ignores non-auth statuses', () {
    expect(isUnauthorizedStatus(null), isFalse);
    expect(isUnauthorizedStatus(400), isFalse);
    expect(isUnauthorizedStatus(404), isFalse);
    expect(isUnauthorizedStatus(500), isFalse);
  });
}
