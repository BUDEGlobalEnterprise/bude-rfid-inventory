import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/adapters/camera_preview_adapter.dart';
import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/hardware/providers.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/operational_components.dart';
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
  StreamSubscription<ScanEvent>? _sub;
  String? _scannerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  Future<void> _startScanning() async {
    final adapter = ref.read(barcodeAdapterProvider);
    if (adapter == null) return;
    try {
      _sub = adapter.events.listen(
        _onScanEvent,
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _scannerError = error.toString());
        },
      );
      await adapter.startScan();
      if (mounted) setState(() => _scannerError = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _scannerError = error.toString());
    }
  }

  Future<void> _stopScanning() async {
    final adapter = ref.read(barcodeAdapterProvider);
    await _sub?.cancel();
    _sub = null;
    await adapter?.stopScan();
  }

  Future<void> _onScanEvent(ScanEvent event) async {
    final barcode = event.barcode;
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

  void _undoLast() {
    if (_items.isEmpty) return;
    setState(() => _items.removeAt(0));
  }

  double get _totalQty => _items.fold<double>(0, (sum, item) => sum + item.qty);

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
              icon: const Icon(Icons.undo),
              tooltip: context.l10n.undoLastScan,
              onPressed: _undoLast,
            ),
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
          _ScanSessionSummary(
            itemCount: _items.length,
            totalQty: _totalQty,
            isResolving: isResolving,
            hasCamera: hasCamera,
          ),
          if (_scannerError != null)
            MaterialBanner(
              content: Text(_scannerError!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _scannerError = null),
                  child: Text(context.l10n.dismiss),
                ),
              ],
            ),
          Expanded(
            child: _items.isEmpty
                ? EmptyStateView(
                    icon: Icons.qr_code_scanner,
                    title: context.l10n.scanningActive,
                    subtitle: context.l10n.scanningActiveSubtitle,
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
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(context.l10n.useNItems(_items.length)),
                onPressed: _useItems,
              ),
            ),
    );
  }
}

class _ScanSessionSummary extends StatelessWidget {
  final int itemCount;
  final double totalQty;
  final bool isResolving;
  final bool hasCamera;

  const _ScanSessionSummary({
    required this.itemCount,
    required this.totalQty,
    required this.isResolving,
    required this.hasCamera,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          BudeStatusChip(
            label: isResolving
                ? context.l10n.resolvingScan
                : context.l10n.scannerReady,
            icon: isResolving ? Icons.sync : Icons.sensors,
            color: isResolving ? scheme.tertiary : scheme.primary,
          ),
          BudeStatusChip(
            label: hasCamera
                ? context.l10n.cameraView
                : context.l10n.hardwareStream,
            icon: hasCamera ? Icons.camera_alt_outlined : Icons.memory,
            color: scheme.secondary,
          ),
          BudeSummaryPill(
            icon: Icons.inventory_2_outlined,
            label: context.l10n.itemsLabel,
            value: '$itemCount',
          ),
          BudeSummaryPill(
            icon: Icons.functions,
            label: context.l10n.totalQty,
            value: formatOperationalQty(totalQty),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.item.itemCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BudeQuantityControl(
                value: item.qty,
                min: 0.01,
                onChanged: onQtyChanged,
              ),
              IconButton(
                tooltip: context.l10n.removeItem,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
