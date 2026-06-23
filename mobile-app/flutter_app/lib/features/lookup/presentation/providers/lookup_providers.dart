import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/epc_remote_data_source.dart';

final epcDataSourceProvider = Provider<EpcRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return EpcRemoteDataSource(apiClient.dio);
});
