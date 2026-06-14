import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/datasources/warehouse_remote_data_source.dart';
import '../../data/warehouse_repository_impl.dart';
import '../../domain/entities/warehouse_stock_line.dart';
import '../../domain/repositories/warehouse_repository.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WarehouseRepositoryImpl(
    remote: WarehouseRemoteDataSourceImpl(apiClient.dio),
  );
});

final warehouseListProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(warehouseRepositoryProvider);
  final result = await repo.listWarehouses();
  return result.fold(
    (failure) => throw failure,
    (names) => names,
  );
});

final warehouseStockProvider = FutureProvider.family
    .autoDispose<List<WarehouseStockLine>, String>((ref, warehouse) async {
  final repo = ref.watch(warehouseRepositoryProvider);
  final result = await repo.getStock(warehouse);
  return result.fold(
    (failure) => throw failure,
    (lines) => lines,
  );
});
