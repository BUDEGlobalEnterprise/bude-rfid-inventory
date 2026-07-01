import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final profileProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).get();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        data: (employee) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(title: const Text('Employee'), subtitle: Text(employee?.employee ?? '')),
            ListTile(title: const Text('Name'), subtitle: Text(employee?.employeeName ?? '')),
            ListTile(title: const Text('Company'), subtitle: Text(employee?.company ?? '')),
            ListTile(title: const Text('Department'), subtitle: Text(employee?.department ?? '')),
            ListTile(title: const Text('Designation'), subtitle: Text(employee?.designation ?? '')),
          ],
        ),
        error: (_, __) => const Center(child: Text('Unable to load profile.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
