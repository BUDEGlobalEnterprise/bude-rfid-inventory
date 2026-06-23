import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/asset_remote_data_source.dart';

final assetDataSourceProvider = Provider<AssetRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AssetRemoteDataSource(apiClient.dio);
});

/// Filter set for the asset list. Equatable-by-value via the record type.
typedef AssetFilter = ({
  String? search,
  String? location,
  String? status,
  String? category,
});

final assetListProvider = FutureProvider.family
    .autoDispose<List<AssetSummary>, AssetFilter>((ref, f) {
  return ref.watch(assetDataSourceProvider).listAssets(
        search: f.search,
        location: f.location,
        status: f.status,
        category: f.category,
      );
});

final assetDetailProvider =
    FutureProvider.family.autoDispose<AssetDetail, String>((ref, name) {
  return ref.watch(assetDataSourceProvider).getAsset(name);
});

final assetMovementsProvider = FutureProvider.family
    .autoDispose<List<AssetMovementRow>, String>((ref, asset) {
  return ref.watch(assetDataSourceProvider).getMovements(asset);
});

final assetLocationsProvider =
    FutureProvider.autoDispose<List<AssetLocation>>((ref) {
  return ref.watch(assetDataSourceProvider).listLocations();
});

final assetCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(assetDataSourceProvider).listCategories();
});

final assetMaintenanceLogsProvider = FutureProvider.family
    .autoDispose<List<MaintenanceLog>, String>((ref, asset) {
  return ref.watch(assetDataSourceProvider).listMaintenanceLogs(asset);
});
