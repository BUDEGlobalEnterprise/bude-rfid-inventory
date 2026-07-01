import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/salary_repository.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final salarySlipsProvider = FutureProvider((ref) {
  return ref.watch(salaryRepositoryProvider).list();
});

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slips = ref.watch(salarySlipsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary slips')),
      body: slips.when(
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (_, index) {
            final row = rows[index];
            return ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(row.name),
              subtitle: Text('${row.startDate} to ${row.endDate}'),
              trailing: Text(row.netPay.toString()),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Unable to load salary slips.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
