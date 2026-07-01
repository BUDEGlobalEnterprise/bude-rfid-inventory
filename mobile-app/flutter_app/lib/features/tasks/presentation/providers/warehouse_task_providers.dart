import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../transfer/presentation/providers/transfer_providers.dart'
    show operationCompanyProvider;
import '../../data/warehouse_task_remote_data_source.dart';
import '../../domain/warehouse_task.dart';

final warehouseTaskRemoteProvider =
    Provider<WarehouseTaskRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WarehouseTaskRemoteDataSource(apiClient.dio);
});

final warehouseTasksProvider =
    FutureProvider.autoDispose<List<WarehouseTask>>((ref) async {
  final company = await ref.watch(operationCompanyProvider.future);
  return ref.watch(warehouseTaskRemoteProvider).listOpen(company: company);
});

final currentUsernameProvider = Provider<String?>((ref) {
  final state = ref.watch(authNotifierProvider);
  if (state is Authenticated) return state.session.username;
  return null;
});
