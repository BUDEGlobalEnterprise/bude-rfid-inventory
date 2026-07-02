import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../../../core/widgets/last_refreshed_label.dart';
import '../../../core/widgets/snackbars.dart';
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

final employeeDocumentsProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).documents();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final documents = ref.watch(employeeDocumentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(profileProvider);
              ref.invalidate(employeeDocumentsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profile.when(
        data: (cached) {
          final employee = cached.data;
          if (employee == null) {
            return const Center(child: Text('No employee profile found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LastRefreshedLabel(
                fetchedAt: cached.fetchedAt,
                fromCache: cached.fromCache,
              ),
              _ProfileSection(
                title: 'Job',
                rows: [
                  _ProfileRow('Employee', employee.employee),
                  _ProfileRow('Name', employee.employeeName),
                  _ProfileRow('Company', employee.company),
                  _ProfileRow('Department', employee.department),
                  _ProfileRow('Designation', employee.designation),
                  _ProfileRow('Date joined', employee.dateOfJoining),
                  _ProfileRow('Reports to', employee.reportsTo),
                ],
              ),
              _ProfileSection(
                title: 'Contact',
                rows: [
                  _ProfileRow('Mobile', employee.cellNumber),
                  _ProfileRow('Company email', employee.companyEmail),
                  _ProfileRow('Personal email', employee.personalEmail),
                ],
              ),
              _ProfileSection(
                title: 'Emergency',
                rows: [
                  _ProfileRow('Contact', employee.emergencyContact),
                  _ProfileRow('Phone', employee.emergencyPhoneNumber),
                  _ProfileRow('Relation', employee.emergencyRelation),
                ],
              ),
              const SizedBox(height: 8),
              Text('Documents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              documents.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No employee documents found.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final row in rows)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              row.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.description_outlined,
                            ),
                            title: Text(row.fileName),
                            subtitle: Text(row.isPrivate ? 'Private' : 'Public'),
                            trailing: IconButton(
                              tooltip: 'Copy document link',
                              onPressed: row.fileUrl.isEmpty
                                  ? null
                                  : () => _copyDocumentLink(context, row),
                              icon: const Icon(Icons.link),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                error: (_, __) => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to load employee documents.'),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        },
        error: (_, __) => const Center(child: Text('Unable to load profile.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _copyDocumentLink(
    BuildContext context,
    EmployeeDocument document,
  ) async {
    await Clipboard.setData(ClipboardData(text: document.fileUrl));
    if (context.mounted) {
      showSuccessSnackBar(context, 'Document link copied.');
    }
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});

  final String title;
  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => row.value.isNotEmpty).toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in visibleRows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(row.label),
                subtitle: Text(row.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow {
  const _ProfileRow(this.label, this.value);

  final String label;
  final String value;
}
