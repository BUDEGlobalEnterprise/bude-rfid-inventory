import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import 'providers/masters_providers.dart';

/// Hub listing every editable master. Manager-gated (nav + router guard).
class MastersHubScreen extends ConsumerWidget {
  const MastersHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(mastersCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Master Data')),
      body: catalogAsync.when(
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load masters: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (masters) => masters.isEmpty
            ? const EmptyStateView(
                icon: Icons.category_outlined,
                title: 'No masters available',
                subtitle: 'Nothing to manage here yet.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(mastersCatalogProvider),
                child: ListView.separated(
                  itemCount: masters.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final m = masters[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(m.label),
                      subtitle: Text(m.doctype),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/masters/${m.key}'),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
