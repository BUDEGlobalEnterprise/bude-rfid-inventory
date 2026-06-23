import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/item_model.dart';
import '../models/item_stock_model.dart';
import '../models/stock_ledger_entry_model.dart';

abstract class ItemRemoteDataSource {
  Future<List<ItemModel>> search(
    String query, {
    int limit,
    int page,
    String? warehouse,
    String? itemGroup,
    bool inStock,
  });
  Future<List<String>> listGroups();
  Future<ItemModel> getByBarcode(String barcode);
  Future<List<ItemStockModel>> getStock(String itemCode, {String? warehouse});
  Future<List<StockLedgerEntryModel>> getLedger(
    String itemCode, {
    String? warehouse,
    int limit,
  });
}

class ItemRemoteDataSourceImpl implements ItemRemoteDataSource {
  final Dio dio;
  ItemRemoteDataSourceImpl(this.dio);

  @override
  Future<List<ItemModel>> search(
    String query, {
    int limit = 20,
    int page = 0,
    String? warehouse,
    String? itemGroup,
    bool inStock = false,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.items.search',
      data: {
        'query': query,
        'limit': limit,
        'page': page,
        if (warehouse != null && warehouse.isNotEmpty) 'warehouse': warehouse,
        if (itemGroup != null && itemGroup.isNotEmpty) 'item_group': itemGroup,
        if (inStock) 'in_stock': '1',
      },
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(ItemModel.fromJson).toList();
  }

  @override
  Future<List<String>> listGroups() async {
    final body = await _call(
      '/api/method/bude_api.api.items.list_groups',
      data: {},
    );
    return (body['data'] as List).cast<String>();
  }

  @override
  Future<ItemModel> getByBarcode(String barcode) async {
    final body = await _call(
      '/api/method/bude_api.api.items.get_by_barcode',
      data: {'barcode': barcode},
    );
    return ItemModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ItemStockModel>> getStock(
    String itemCode, {
    String? warehouse,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.items.get_stock',
      data: {
        'item_code': itemCode,
        if (warehouse != null) 'warehouse': warehouse,
      },
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(ItemStockModel.fromJson).toList();
  }

  @override
  Future<List<StockLedgerEntryModel>> getLedger(
    String itemCode, {
    String? warehouse,
    int limit = 50,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.items.get_ledger',
      data: {
        'item_code': itemCode,
        if (warehouse != null) 'warehouse': warehouse,
        'limit': limit,
      },
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StockLedgerEntryModel.fromJson).toList();
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(path, data: data);
      // Frappe wraps every /api/method return value under "message".
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw const ServerException('Unexpected response shape from server.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        final message = body['message'] as String? ?? 'Request failed.';
        final code = body['code'] as String?;
        if (code == 'ITEM_NOT_FOUND') {
          throw NotFoundException(message);
        }
        if (code == 'VALIDATION_REQUIRED') {
          throw ValidationException(message);
        }
        throw ServerException(message);
      }
      return body;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const AuthException('Authentication required.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException(e.message ?? 'Network unreachable.');
      }
      throw ServerException(
        e.message ?? 'Server error.',
        statusCode: status,
      );
    }
  }
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}
