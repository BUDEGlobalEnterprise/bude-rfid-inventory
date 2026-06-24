import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/features/inventory/data/datasources/item_local_data_source.dart';
import 'package:bude_inventory/features/inventory/data/datasources/item_remote_data_source.dart';
import 'package:bude_inventory/features/inventory/data/item_repository_impl.dart';
import 'package:bude_inventory/features/inventory/data/models/item_model.dart';
import 'package:bude_inventory/features/inventory/data/models/item_stock_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements ItemRemoteDataSource {}

// ponytail: no-op local so tests exercise the network path only
class _NoopLocal implements ItemLocalDataSource {
  @override
  void putSearchResult(String k, List<ItemModel> items) {}
  @override
  List<ItemModel>? getSearchResult(String k) => null;
  @override
  void putItem(String itemCode, ItemModel item) {}
  @override
  ItemModel? getItem(String itemCode) => null;
}

void main() {
  late _MockRemote remote;
  late ItemRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = ItemRepositoryImpl(remote: remote, local: _NoopLocal());
  });

  group('search', () {
    test('maps models to entities on success', () async {
      when(
        () => remote.search(
          'widget',
          limit: 20,
          page: 0,
          warehouse: null,
          itemGroup: null,
          inStock: false,
        ),
      ).thenAnswer(
        (_) async => [
          const ItemModel(itemCode: 'A', itemName: 'Widget A'),
          const ItemModel(itemCode: 'B', itemName: 'Widget B'),
        ],
      );

      final result = await repo.search('widget');

      result.fold(
        (_) => fail('expected Right'),
        (items) {
          expect(items, hasLength(2));
          expect(items.first.itemCode, 'A');
        },
      );
    });

    test('maps NetworkException to NetworkFailure', () async {
      when(
        () => remote.search(
          any(),
          limit: any(named: 'limit'),
          page: any(named: 'page'),
          warehouse: any(named: 'warehouse'),
          itemGroup: any(named: 'itemGroup'),
          inStock: any(named: 'inStock'),
        ),
      ).thenThrow(const NetworkException('offline'));

      final result = await repo.search('q');

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getByBarcode', () {
    test('maps NotFoundException to ValidationFailure', () async {
      when(() => remote.getByBarcode('UNKNOWN'))
          .thenThrow(const NotFoundException('no item'));

      final result = await repo.getByBarcode('UNKNOWN');

      result.fold(
        (f) {
          expect(f, isA<ValidationFailure>());
          expect(f.message, 'no item');
        },
        (_) => fail('expected Left'),
      );
    });

    test('returns mapped entity on success', () async {
      when(() => remote.getByBarcode('ABC')).thenAnswer(
        (_) async => const ItemModel(itemCode: 'ITEM-1', itemName: 'Thing'),
      );

      final result = await repo.getByBarcode('ABC');

      result.fold(
        (_) => fail('expected Right'),
        (item) => expect(item.itemCode, 'ITEM-1'),
      );
    });
  });

  group('getStock', () {
    test('returns mapped list', () async {
      when(() => remote.getStock('ITEM-1', warehouse: null)).thenAnswer(
        (_) async => [
          const ItemStockModel(
            warehouse: 'Stores - X',
            actualQty: 10,
            reservedQty: 1,
            orderedQty: 0,
            projectedQty: 9,
          ),
        ],
      );

      final result = await repo.getStock('ITEM-1');

      result.fold(
        (_) => fail('expected Right'),
        (rows) {
          expect(rows, hasLength(1));
          expect(rows.first.warehouse, 'Stores - X');
          expect(rows.first.actualQty, 10.0);
        },
      );
    });

    test('forwards warehouse filter when provided', () async {
      when(() => remote.getStock('I', warehouse: 'W'))
          .thenAnswer((_) async => []);

      await repo.getStock('I', warehouse: 'W');

      verify(() => remote.getStock('I', warehouse: 'W')).called(1);
    });
  });
}
