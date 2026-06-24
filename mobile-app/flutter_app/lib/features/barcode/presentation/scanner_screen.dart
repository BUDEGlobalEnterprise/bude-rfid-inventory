import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/adapters/barcode_adapter.dart';
import '../../../core/hardware/adapters/camera_preview_adapter.dart';
import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/hardware/providers.dart';
import '../../../core/utils/locale_ext.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  StreamSubscription<ScanEvent>? _sub;
  bool _handled = false;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _start() async {
    final adapter = ref.read(barcodeAdapterProvider);
    if (adapter == null) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = 'No barcode scanner is available.';
        });
      }
      return;
    }

    try {
      _sub = adapter.events.listen(
        _onScan,
        onError: (Object error) {
          if (!mounted || _handled) return;
          setState(() {
            _starting = false;
            _error = error.toString();
          });
        },
      );
      await adapter.startScan();
      if (mounted) setState(() => _starting = false);
    } catch (error) {
      if (!mounted || _handled) return;
      setState(() {
        _starting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _stop() async {
    final sub = _sub;
    final adapter = ref.read(barcodeAdapterProvider);
    _sub = null;
    await sub?.cancel();
    await adapter?.stopScan();
  }

  void _onScan(ScanEvent event) {
    if (_handled || event.barcode.isEmpty) return;
    _handled = true;
    unawaited(_stop());
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final adapter = ref.watch(barcodeAdapterProvider);
    final CameraPreviewAdapter? preview = adapter is CameraPreviewAdapter
        ? adapter as CameraPreviewAdapter
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.scan)),
      body: Stack(
        children: [
          if (preview != null)
            Positioned.fill(child: preview.buildPreview())
          else
            _HardwareScannerView(adapter: adapter),
          if (preview != null)
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_starting) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HardwareScannerView extends StatelessWidget {
  final BarcodeAdapter? adapter;

  const _HardwareScannerView({required this.adapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              adapter == null
                  ? 'Scanner unavailable'
                  : 'Ready: ${adapter!.vendor}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
