import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/presentation/auth_controller.dart';

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
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Languages'),
            subtitle: const Text('English and Arabic supported'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
