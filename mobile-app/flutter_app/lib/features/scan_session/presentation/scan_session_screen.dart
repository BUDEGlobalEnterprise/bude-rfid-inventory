import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/adapters/camera_preview_adapter.dart';
import '../../../core/hardware/providers.dart';
import '../../../core/utils/locale_ext.dart';
import '../../inventory/presentation/providers/item_search_notifier.dart';
import '../domain/scan_session_mode.dart';
import '../domain/scanned_item.dart';

class ScanSessionScreen extends ConsumerStatefulWidget {
  final ScanSessionMode mode;
  const ScanSessionScreen({super.key, required this.mode});

  @override
  ConsumerState<ScanSessionScreen> createState() => _ScanSessionScreenState();
}

class _ScanSessionScreenState extends ConsumerState<ScanSessionScreen> {
  final List<ScannedItem> _items = [];
  final Set<String> _resolving = {};
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  Future<void> _startScanning() async {
    final adapter = ref.read(barcodeAdapterProvider);
    if (adapter == null) return;
    await adapter.startScan();
    _sub = adapter.events.listen(_onScanEvent);
  }

  Future<void> _stopScanning() async {
    await _sub?.cancel();
    _sub = null;
    final adapter = ref.read(barcodeAdapterProvider);
    await adapter?.stopScan();
  }

  Future<void> _onScanEvent(dynamic event) async {
    final barcode = event.barcode as String;
    if (_resolving.contains(barcode)) return;
    if (_items.any((i) => i.barcode == barcode)) {
      // Duplicate — bump qty instead
      setState(() {
        final idx = _items.indexWhere((i) => i.barcode == barcode);
        _items[idx] = _items[idx].copyWith(qty: _items[idx].qty + 1);
      });
      return;
    }

    setState(() => _resolving.add(barcode));
    final useCase = ref.read(getItemByBarcodeUseCaseProvider);
    final result = await useCase(barcode);
    if (!mounted) return;

    setState(() {
      _resolving.remove(barcode);
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.barcodeNotFound)),
          );
        },
        (item) {
          _items.insert(
            0,
            ScannedItem(barcode: barcode, item: item),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.itemAdded(item.itemName)),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      );
    });
  }

  void _useItems() {
    _stopScanning();
    context.pop(List<ScannedItem>.from(_items));
  }

  void _clear() => setState(() => _items.clear());

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adapter = ref.watch(barcodeAdapterProvider);
    final hasCamera = adapter is CameraPreviewAdapter;
    final isResolving = _resolving.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.scanSession),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear',
              onPressed: _clear,
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasCamera)
            SizedBox(
              height: 220,
              child: (adapter as CameraPreviewAdapter).buildPreview(),
            ),
          _StatusBar(isResolving: isResolving),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.scanningActive,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) => _ScannedItemTile(
                      item: _items[i],
                      onRemove: () => setState(() => _items.removeAt(i)),
                      onQtyChanged: (q) => setState(() {
                        _items[i] = _items[i].copyWith(qty: q);
                      }),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: Text(context.l10n.useNItems(_items.length)),
              onPressed: _useItems,
            ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final bool isResolving;
  const _StatusBar({required this.isResolving});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isResolving ? 32 : 0,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: isResolving
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.resolving,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ScannedItemTile extends StatelessWidget {
  final ScannedItem item;
  final VoidCallback onRemove;
  final ValueChanged<double> onQtyChanged;

  const _ScannedItemTile({
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.item.itemName),
      subtitle: Text(item.item.itemCode),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            child: TextFormField(
              key: ValueKey(item.barcode),
              initialValue: _fmt(item.qty),
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null && q > 0) onQtyChanged(q);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

