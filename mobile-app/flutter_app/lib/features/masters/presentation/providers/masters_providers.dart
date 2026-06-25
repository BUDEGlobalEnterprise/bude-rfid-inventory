import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/masters_remote_data_source.dart';
import '../../domain/master_def.dart';

final mastersDataSourceProvider = Provider<MastersRemoteDataSource>((ref) {
  return MastersRemoteDataSource(ref.watch(apiClientProvider).dio);
});

/// Catalog of editable masters + their field schema.
final mastersCatalogProvider =
    FutureProvider.autoDispose<List<MasterDef>>((ref) async {
  return ref.watch(mastersDataSourceProvider).listMasters();
});

typedef RecordsArgs = ({String key, String? search});

final masterRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, RecordsArgs>((ref, args) async {
  return ref.watch(mastersDataSourceProvider).listRecords(
        args.key,
        search: args.search,
      );
});

typedef RecordArgs = ({String key, String name});

final masterRecordProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, RecordArgs>((ref, args) async {
  return ref.watch(mastersDataSourceProvider).getRecord(args.key, args.name);
});
