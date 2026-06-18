import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/company_repository_impl.dart';
import '../../data/datasources/company_remote_data_source.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CompanyRepositoryImpl(
    CompanyRemoteDataSourceImpl(apiClient.dio),
  );
});

final companiesProvider =
    FutureProvider.autoDispose<List<Company>>((ref) async {
  final repo = ref.watch(companyRepositoryProvider);
  final result = await repo.listCompanies();
  return result.fold(
    (failure) => throw failure,
    (companies) => companies,
  );
});
