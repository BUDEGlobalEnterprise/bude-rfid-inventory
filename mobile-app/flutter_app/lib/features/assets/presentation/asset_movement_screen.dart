import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../data/asset_op_submitters.dart';
import 'providers/asset_providers.dart';

/// Check-in / check-out / transfer of assets → queues an Asset Movement.
/// Full-screen task flow (outside the shell).
class AssetMovementScreen extends ConsumerStatefulWidget {
  final String? initialAsset;
  const AssetMovementScreen({super.key, this.initialAsset});

  @override
  ConsumerState<AssetMovementScreen> createState() =>
      _AssetMovementScreenState();
}

class _AssetMovementScreenState extends ConsumerState<AssetMovementScreen> {
  final _assetCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();
  final List<String> _assets = [];
  String _purpose = 'Transfer';
  String? _targetLocation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAsset != null && widget.initialAsset!.isNotEmpty) {
      _assets.add(widget.initialAsset!);
    }
  }

  @override
  void dispose() {
    _assetCtrl.dispose();
    _employeeCtrl.dispose();
    super.dispose();
  }

  void _addAsset() {
    final v = _assetCtrl.text.trim();
    if (v.isEmpty || _assets.contains(v)) return;
    setState(() {
      _assets.add(v);
      _assetCtrl.clear();
    });
  }

  bool get _valid {
    if (_assets.isEmpty) return false;
    if (_purpose == 'Transfer' || _purpose == 'Receipt') {
      return _targetLocation != null;
    }
    // Issue
    return _targetLocation != null || _employeeCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'assets': _assets,
      'purpose': _purpose,
      if (_targetLocation != null) 'target_location': _targetLocation,
      if (_employeeCtrl.text.trim().isNotEmpty)
        'to_employee': _employeeCtrl.text.trim(),
    };
    await ref
        .read(syncQueueProvider)
        .enqueue(type: kAssetMovementOpType, payload: payload);
    await ref.read(syncEngineProvider).kick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Asset movement queued')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(assetLocationsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Move / Check-in / Check-out')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _purpose,
            decoration: const InputDecoration(
              labelText: 'Purpose',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'Issue', child: Text('Issue (check-out)'),),
              DropdownMenuItem(
                  value: 'Receipt', child: Text('Receipt (check-in)'),),
              DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
            ],
            onChanged: (v) => setState(() => _purpose = v ?? 'Transfer'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _targetLocation,
            decoration: const InputDecoration(
              labelText: 'Target location',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final l in locations)
                DropdownMenuItem(value: l.name, child: Text(l.name)),
            ],
            onChanged: (v) => setState(() => _targetLocation = v),
          ),
          if (_purpose == 'Issue') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _employeeCtrl,
              decoration: const InputDecoration(
                labelText: 'To employee (ID)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const Divider(height: 32),
          Text('Assets', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _assetCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Asset name',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addAsset(),
                ),
              ),
              IconButton.filled(
                onPressed: _addAsset,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final a in _assets)
            ListTile(
              dense: true,
              leading: const Icon(Icons.precision_manufacturing),
              title: Text(a),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _assets.remove(a)),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _valid && !_submitting ? _submit : null,
            icon: const Icon(Icons.send),
            label: Text(_submitting ? 'Queuing…' : 'Queue movement'),
          ),
        ],
      ),
    );
  }
}
