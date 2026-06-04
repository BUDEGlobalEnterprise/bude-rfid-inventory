import 'package:bude_inventory/features/onboarding/data/connection_validator_impl.dart';
import 'package:bude_inventory/features/onboarding/domain/connection_check_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

const _versionsPath = '/api/method/frappe.utils.change_log.get_versions';
const _pingPath = '/api/method/bude_api.api.health.ping';

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

  test('returns ConnectionUnreachable for empty URL', () async {
    final result = await validator.check('   ');
    expect(result, isA<ConnectionUnreachable>());
  });

  test('returns ConnectionOk when both probes succeed', () async {
    mockGet(
      _versionsPath,
      ok({
        'message': {
          'erpnext': {'version': '15.0.0'},
          'frappe': {'version': '15.0.0'},
        },
      }),
    );
    mockGet(
      _pingPath,
      ok({
        'message': {
          'status': 'ok',
          'service': 'bude_api',
          'version': '0.1.0',
        },
      }),
    );

    final result = await validator.check('https://erp.example.com');
    expect(
      result,
      isA<ConnectionOk>()
          .having((r) => r.erpnextVersion, 'erpnextVersion', '15.0.0')
          .having((r) => r.budeApiVersion, 'budeApiVersion', '0.1.0'),
    );
  });

  test('trailing slash in URL is stripped before probes', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path.contains('change_log')) {
        return ok({
          'message': {
            'erpnext': {'version': '15.0.0'},
          },
        });
      }
      return ok({
        'message': {'version': '0.1.0'},
      });
    });

    final factoryUrls = <String>[];
    final v = ConnectionValidatorImpl(
      dioFactory: (baseUrl) {
        factoryUrls.add(baseUrl);
        return dio;
      },
    );
    await v.check('https://erp.example.com/');
    expect(factoryUrls.single, 'https://erp.example.com');
  });

  test('returns ConnectionUnreachable on connection timeout', () async {
    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenThrow(dioErr(type: DioExceptionType.connectionTimeout));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionUnreachable>());
  });

  test('returns ConnectionNotErpNext on 404 from version probe', () async {
    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenThrow(dioErr(status: 404));

    final result = await validator.check('https://nope.example.com');
    expect(result, isA<ConnectionNotErpNext>());
  });

  test(
    'returns ConnectionNotErpNext when erpnext key missing from versions',
    () async {
      mockGet(
        _versionsPath,
        ok({
          'message': {
            'frappe': {'version': '15.0.0'},
            // no 'erpnext' key
          },
        }),
      );

      final result = await validator.check('https://frappe-only.example.com');
      expect(result, isA<ConnectionNotErpNext>());
      verifyNever(() => dio.get<Map<String, dynamic>>(_pingPath));
    },
  );

  test('returns ConnectionBudeApiMissing when ping returns 404', () async {
    mockGet(
      _versionsPath,
      ok({
        'message': {
          'erpnext': {'version': '15.0.0'},
        },
      }),
    );
    mockGetThrows(_pingPath, dioErr(status: 404));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionBudeApiMissing>());
  });

  test('returns ConnectionBudeApiMissing when ping returns 500', () async {
    mockGet(
      _versionsPath,
      ok({
        'message': {
          'erpnext': {'version': '15.0.0'},
        },
      }),
    );
    mockGetThrows(_pingPath, dioErr(status: 500));

    final result = await validator.check('https://erp.example.com');
    expect(result, isA<ConnectionBudeApiMissing>());
  });
}
