import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/features/masters/data/masters_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late MastersRemoteDataSource dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = MastersRemoteDataSource(dio);
  });

  Response<Map<String, dynamic>> response(Object? data) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'message': {'ok': true, 'data': data},
        },
      );

  void whenGet(Object? data) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response(data));
  }

  void whenGetNoParams(Object? data) {
    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => response(data));
  }

  void whenPost(Object? data) {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => response(data));
  }

  test('listMasters maps the catalog including nested field schema', () async {
    whenGetNoParams([
      {
        'key': 'warehouse',
        'label': 'Warehouses',
        'doctype': 'Warehouse',
        'can_disable': true,
        'fields': [
          {
            'name': 'warehouse_name',
            'label': 'Warehouse Name',
            'type': 'text',
            'required': true,
          },
          {
            'name': 'company',
            'label': 'Company',
            'type': 'link',
            'required': true,
            'link': 'Company',
          },
        ],
      },
    ]);

    final masters = await dataSource.listMasters();

    expect(masters, hasLength(1));
    expect(masters.single.key, 'warehouse');
    expect(masters.single.doctype, 'Warehouse');
    expect(masters.single.canDisable, isTrue);
    expect(masters.single.fields, hasLength(2));
    expect(masters.single.fields.last.link, 'Company');
    expect(masters.single.fields.last.required, isTrue);

    verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.list_masters',
      ),
    ).called(1);
  });

  test('listRecords sends master, optional search, and limit', () async {
    whenGet([
      {'name': 'Bude Global', 'company_name': 'Bude Global'},
    ]);

    final records = await dataSource.listRecords('company', search: 'bude');

    expect(records, hasLength(1));
    expect(records.single['name'], 'Bude Global');

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.list_records',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'master': 'company', 'search': 'bude', 'limit': 50});
  });

  test('listRecords omits search when empty', () async {
    whenGet([]);

    await dataSource.listRecords('warehouse');

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.list_records',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'master': 'warehouse', 'limit': 50});
  });

  test('getRecord sends master and name and returns the row', () async {
    whenGet({'name': 'Bude Global', 'company_name': 'Bude Global'});

    final record = await dataSource.getRecord('company', 'Bude Global');

    expect(record['company_name'], 'Bude Global');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.get_record',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'master': 'company', 'name': 'Bude Global'});
  });

  test('linkOptions sends doctype and optional search', () async {
    whenGet(['Bude Global', 'Acme']);

    final options = await dataSource.linkOptions('Company', search: 'bu');

    expect(options, ['Bude Global', 'Acme']);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.list_link_options',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'doctype': 'Company', 'search': 'bu'});
  });

  test('create posts master and values, returns the server-assigned name', () async {
    whenPost({'name': 'Floor - A'});

    final name = await dataSource.create('warehouse', {
      'warehouse_name': 'Floor',
      'company': 'Bude Global',
    });

    expect(name, 'Floor - A');
    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.create_record',
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {
      'master': 'warehouse',
      'values': {'warehouse_name': 'Floor', 'company': 'Bude Global'},
    });
  });

  test('update posts master, name, and values', () async {
    whenPost({'name': 'Floor - A'});

    await dataSource.update('warehouse', 'Floor - A', {
      'warehouse_name': 'Floor Updated',
    });

    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.update_record',
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {
      'master': 'warehouse',
      'name': 'Floor - A',
      'values': {'warehouse_name': 'Floor Updated'},
    });
  });

  test('setDisabled posts master, name, and disabled flag', () async {
    whenPost(null);

    await dataSource.setDisabled('warehouse', 'Floor - A', true);

    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.masters.set_disabled',
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {
      'master': 'warehouse',
      'name': 'Floor - A',
      'disabled': true,
    });
  });

  test('401 response maps to AuthException', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
      ),
    );

    expect(dataSource.listMasters(), throwsA(isA<AuthException>()));
  });

  test('connection error maps to NetworkException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      dataSource.getRecord('company', 'Bude Global'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('unknown master (ok:false envelope) maps to ServerException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'message': {
            'ok': false,
            'message': "Unknown master 'nope'.",
            'code': 'VALIDATION_UNKNOWN_MASTER',
          },
        },
      ),
    );

    expect(
      dataSource.listRecords('nope'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          "Unknown master 'nope'.",
        ),
      ),
    );
  });

  test('other 5xx errors map to ServerException with status code', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
        ),
      ),
    );

    expect(
      dataSource.listMasters(),
      throwsA(
        isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          502,
        ),
      ),
    );
  });
}
