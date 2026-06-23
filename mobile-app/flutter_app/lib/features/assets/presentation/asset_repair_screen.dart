import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../data/asset_op_submitters.dart';

/// Report an asset failure → queues an Asset Repair (status Pending).
/// Full-screen task flow (outside the shell).
class AssetRepairScreen extends ConsumerStatefulWidget {
  final String? initialAsset;
  const AssetRepairScreen({super.key, this.initialAsset});

  @override
  ConsumerState<AssetRepairScreen> createState() => _AssetRepairScreenState();
}

class _AssetRepairScreenState extends ConsumerState<AssetRepairScreen> {
  final _assetCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAsset != null) _assetCtrl.text = widget.initialAsset!;
  }

  @override
  void dispose() {
    _assetCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'asset': _assetCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      if (double.tryParse(_costCtrl.text.trim()) != null)
        'repair_cost': double.parse(_costCtrl.text.trim()),
    };
    await ref
        .read(syncQueueProvider)
        .enqueue(type: kAssetRepairOpType, payload: payload);
    await ref.read(syncEngineProvider).kick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Repair report queued')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Repair')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _assetCtrl,
            decoration: const InputDecoration(
              labelText: 'Asset name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Failure description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _costCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Estimated repair cost (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _assetCtrl.text.trim().isNotEmpty && !_submitting
                ? _submit
                : null,
            icon: const Icon(Icons.build),
            label: Text(_submitting ? 'Queuing…' : 'Queue repair report'),
          ),
        ],
      ),
    );
  }
}
