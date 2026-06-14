import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/utils/locale_ext.dart';
import '../domain/entities/item.dart';
import 'providers/item_search_notifier.dart';

class ItemSearchScreen extends ConsumerStatefulWidget {
  const ItemSearchScreen({super.key});

  @override
  ConsumerState<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

class _ItemSearchScreenState extends ConsumerState<ItemSearchScreen> {
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await context.push<ScanEvent>('/scan');
    if (result == null || !mounted) return;

    final repository = ref.read(itemRepositoryProvider);
    final lookup = await repository.getByBarcode(result.barcode);
    if (!mounted) return;

    lookup.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (item) => context.push('/items/${Uri.encodeComponent(item.itemCode)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemSearchNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.searchItems)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openScanner,
        tooltip: 'Scan barcode',
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Item code, name, or barcode',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref
                  .read(itemSearchNotifierProvider.notifier)
                  .onQueryChanged(v),
            ),
          ),
          Expanded(child: _ResultsView(state: state)),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final ItemSearchState state;
  const _ResultsView({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ItemSearchIdle() => const Center(
          child: Text('Type to search items.'),
        ),
      ItemSearchLoading() => const Center(child: CircularProgressIndicator()),
      ItemSearchError(:final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ItemSearchResults(:final items, :final query) =>
        items.isEmpty
            ? Center(child: Text('No items match "$query".'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) => _ItemTile(item: items[i]),
              ),
    };
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.itemName),
      subtitle: Text(item.itemCode),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          context.push('/items/${Uri.encodeComponent(item.itemCode)}'),
    );
  }
}
