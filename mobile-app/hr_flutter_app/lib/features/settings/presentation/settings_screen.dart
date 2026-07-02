import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dialogs.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../sync/presentation/sync_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('ERPNext URL'),
            subtitle: Text(session?.baseUrl ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Signed in as'),
            subtitle: Text(session?.user ?? ''),
          ),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Languages'),
            subtitle: Text('English and Arabic supported'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final pending = ref.watch(syncControllerProvider).operations.length;
              return ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Pending sync'),
                subtitle: Text(
                  pending == 0
                      ? 'Everything is synced'
                      : '$pending operation(s) waiting',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/pending'),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Sign out?',
                message:
                    'This will remove your saved Bude HR session from this device.',
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (confirmed) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
