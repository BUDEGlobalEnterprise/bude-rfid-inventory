import 'package:bude_hr/core/network/api_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts existing bude_api ok envelope', () {
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      {
        'ok': true,
        'data': {'user': 'employee@example.com'},
      },
      (value) => Map<String, dynamic>.from(value as Map),
    );

    expect(envelope.ok, isTrue);
    expect(envelope.data?['user'], 'employee@example.com');
  });

  test('also accepts success envelope for future compatibility', () {
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      {
        'success': true,
        'data': ['Annual Leave'],
      },
      (value) => List<dynamic>.from(value as List),
    );

    expect(envelope.ok, isTrue);
    expect(envelope.data, ['Annual Leave']);
  });
}
