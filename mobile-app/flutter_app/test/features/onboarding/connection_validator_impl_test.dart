import 'package:bude_inventory/features/onboarding/data/connection_validator_impl.dart';
import 'package:bude_inventory/features/onboarding/domain/connection_check_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

const _frappePingPath = '/api/method/frappe.ping';
const _budePingPath = '/api/method/bude_api.api.health.ping';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
  });

  late _MockDio dio;
  late ConnectionValidatorImpl validator;

  setUp(() {
    dio = _MockDio();
    validator = ConnectionValidatorImpl(dioFactory: (_) => dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) => Response(
        requestOptions: RequestOptions(),
        statusCode: 200,
        data: body,
      );

  DioException dioErr({int? status, DioExceptionType? type}) => DioException(
        requestOptions: RequestOptions(),
        type: type ?? DioExceptionType.unknown,
        response: status == null
            ? null
            : Response(requestOptions: RequestOptions(), statusCode: status),
      );

  void mockGet(String path, Response<Map<String, dynamic>> response) {
    when(() => dio.get<Map<String, dynamic>>(path))
        .thenAnswer((_) async => response);
  }

  void mockGetThrows(String path, DioException error) {
    when(() => dio.get<Map<String, dynamic>>(path)).thenThrow(error);
  }

  void stubFrappePongOk() {
    mockGet(_frappePingPath, ok({'message': 'pong'}));
  }

  test('returns ConnectionUnreachable for empty URL', () async {
    final result = await validator.check('   ');
    expect(result, isA<ConnectionUnreachable>());
  });

  test('requires a full URL with scheme', () async {
    final result = await validator.check('erp.example.com');
    expect(result, isA<ConnectionUnreachable>());
    verifyNever(() => dio.get<Map<String, dynamic>>(any()));
  });

  test('rejects public HTTP URLs before probing the server', () async {
    final result = await validator.check('http://erp.example.com');
    expect(result, isA<ConnectionUnreachable>());
    verifyNever(() => dio.get<Map<String, dynamic>>(any()));
  });

  test('rejects localhost HTTP when insecure local URLs are disabled',
      () async {
    final v = ConnectionValidatorImpl(
      dioFactory: (_) => dio,
      allowInsecureLocalNetwork: false,
    );

    final result = await v.check('http://localhost:8000');
    expect(result, isA<ConnectionUnreachable>());
    verifyNever(() => dio.get<Map<String, dynamic>>(any()));
  });

  test('allows localhost HTTP for development checks', () async {
    stubFrappePongOk();
    mockGet(
      _budePingPath,
      ok({
        'message': {'version': '0.2.0'},
      }),
    );

    final result = await validator.check('http://localhost:8000');
    expect(result, isA<ConnectionOk>());
  });

  test('full happy path — both versions propagated', () async {
    stubFrappePongOk();
    mockGet(
      _budePingPath,
      ok({
        'message': {
          'status': 'ok',
          'service': 'bude_api',
          'version': '0.2.0',
          'erpnext_version': '16.6.1',
        },
      }),
    );

    final result = await validator.check('https://erp.example.com');
    expect(
      result,
      isA<ConnectionOk>()
          .having((r) => r.erpnextVersion, 'erpnextVersion', '16.6.1')
          .having((r) => r.budeApiVersion, 'budeApiVersion', '0.2.0'),
    );
  });

  test('erpnext_version null from server → coerced to "unknown"', () async {
    stubFrappePongOk();
    mockGet(
      _budePingPath,
      ok({
        'message': {
          'status': 'ok',
          'version': '0.2.0',
          'erpnext_version': null,
        },
      }),
    );

    final result = await validator.check('https://erp.example.com');
    expect(
      result,
      isA<ConnectionOk>().having(
        (r) => r.erpnextVersion,
        'erpnextVersion',
        'unknown',
      ),
    );
  });

  test('trailing slash in URL is stripped before probes', () async {
    final factoryUrls = <String>[];
    final v = ConnectionValidatorImpl(
      dioFactory: (baseUrl) {
        factoryUrls.add(baseUrl);
        return dio;
      },
    );
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == _frappePingPath) return ok({'message': 'pong'});
      return ok({
        'message': {'version': '0.1.0'},
      });
    });
    await v.check('https://erp.example.com/');
    expect(factoryUrls.single, 'https://erp.example.com');
  });

  test('returns ConnectionUnreachable on connection timeout at Frappe probe',
      () async {
    mockGetThrows(
      _frappePingPath,
      dioErr(type: DioExceptionType.connectionTimeout),
    );

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionUnreachable>());
    verifyNever(() => dio.get<Map<String, dynamic>>(_budePingPath));
  });

  test('returns ConnectionNotErpNext on 404 from Frappe probe', () async {
    mockGetThrows(_frappePingPath, dioErr(status: 404));

    final result = await validator.check('https://nope.example.com');
    expect(result, isA<ConnectionNotErpNext>());
    verifyNever(() => dio.get<Map<String, dynamic>>(_budePingPath));
  });

  test('returns ConnectionBudeApiMissing when bude ping returns 403', () async {
    stubFrappePongOk();
    mockGetThrows(_budePingPath, dioErr(status: 403));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionBudeApiMissing>());
  });

  test('returns ConnectionBudeApiMissing when bude ping returns 404', () async {
    stubFrappePongOk();
    mockGetThrows(_budePingPath, dioErr(status: 404));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionBudeApiMissing>());
  });

  test('returns ConnectionBudeApiMissing when bude ping returns 500', () async {
    stubFrappePongOk();
    mockGetThrows(_budePingPath, dioErr(status: 500));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionBudeApiMissing>());
  });
}
