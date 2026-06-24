import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/adapters/hardware_exceptions.dart';
import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/hardware/providers.dart';
import '../data/epc_remote_data_source.dart';
import 'providers/lookup_providers.dart';

/// Scan-to-locate: resolve an RFID EPC (or barcode) to an asset / item /
/// serial and route to its detail. Full-screen task flow (outside the shell).
class LookupScreen extends ConsumerStatefulWidget {
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends ConsumerState<LookupScreen> {
  final _epcCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  ScanMatch? _match;

  @override
  void dispose() {
    _epcCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final ev = await context.push<ScanEvent>('/scan');
    if (ev == null || !mounted) return;
    _epcCtrl.text = ev.barcode;
    await _resolve();
  }

  Future<void> _readRfid() async {
    final rfid = ref.read(rfidAdapterProvider);
    if (rfid == null) {
      setState(() => _error = 'No RFID reader is available.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _match = null;
    });
    try {
      if (!rfid.isConnected) await rfid.connect();
      final tag = await rfid.readTag();
      if (!mounted) return;
      if (tag == null || tag.epc.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No RFID tag was read.';
        });
        return;
      }
      _epcCtrl.text = tag.epc;
      await _resolve();
    } on VendorSdkUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    } on HardwareOperationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _resolve() async {
    final epc = _epcCtrl.text.trim();
    if (epc.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _match = null;
    });
    try {
      final match = await ref.read(epcDataSourceProvider).resolve(epc);
      if (!mounted) return;
      setState(() => _match = match);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bind(String doctype, String name) async {
    final epc = _epcCtrl.text.trim();
    if (epc.isEmpty || name.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(epcDataSourceProvider).bind(doctype, name.trim(), epc);
      await _resolve();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRfid = ref.watch(rfidAdapterProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan / Lookup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _epcCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'RFID EPC or barcode',
              prefixIcon: Icon(Icons.nfc),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _resolve(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (hasRfid)
                OutlinedButton.icon(
                  onPressed: _loading ? null : _readRfid,
                  icon: const Icon(Icons.nfc),
                  label: const Text('Read RFID'),
                ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(hasRfid ? 'Scan barcode' : 'Scan'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _resolve,
                icon: const Icon(Icons.search),
                label: const Text('Resolve'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (_match != null && !_loading)
            _ResultView(match: _match!, onBind: _bind),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ScanMatch match;
  final void Function(String doctype, String name) onBind;
  const _ResultView({required this.match, required this.onBind});

  @override
  Widget build(BuildContext context) {
    switch (match.matchType) {
      case 'asset':
        final a = match.asset!;
        return _MatchCard(
          icon: Icons.precision_manufacturing,
          title: (a['asset_name'] ?? a['name'] ?? '').toString(),
          lines: [
            'Status: ${a['status'] ?? '—'}',
            'Location: ${a['location'] ?? '—'}',
            'Custodian: ${a['custodian'] ?? '—'}',
          ],
          actionLabel: 'Open asset',
          onAction: () => context.push(
            '/assets/${Uri.encodeComponent((a['name'] ?? '').toString())}',
          ),
        );
      case 'item':
        final i = match.item!;
        return _MatchCard(
          icon: Icons.inventory_2,
          title: (i['item_name'] ?? i['item_code'] ?? '').toString(),
          lines: ['Item code: ${i['item_code'] ?? '—'}'],
          actionLabel: 'Open item',
          onAction: () => context.push(
            '/items/${Uri.encodeComponent((i['item_code'] ?? '').toString())}',
          ),
        );
      case 'serial':
        final s = match.serial!;
        return _MatchCard(
          icon: Icons.qr_code_2,
          title: (s['name'] ?? '').toString(),
          lines: [
            'Item: ${s['item_name'] ?? s['item_code'] ?? '—'}',
            'Status: ${s['status'] ?? '—'}',
          ],
          actionLabel: 'Open item',
          onAction: () => context.push(
            '/items/${Uri.encodeComponent((s['item_code'] ?? '').toString())}',
          ),
        );
      default:
        return _BindCard(onBind: onBind);
    }
  }
}

class _MatchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final String actionLabel;
  final VoidCallback onAction;
  const _MatchCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child:
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the EPC isn't registered — bind it to a record by name.
class _BindCard extends StatefulWidget {
  final void Function(String doctype, String name) onBind;
  const _BindCard({required this.onBind});

  @override
  State<_BindCard> createState() => _BindCardState();
}

class _BindCardState extends State<_BindCard> {
  String _doctype = 'Asset';
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_off),
                const SizedBox(width: 8),
                Text(
                  'Tag not registered',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Bind this EPC to an existing record:'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _doctype,
              decoration: const InputDecoration(
                labelText: 'Record type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Asset', child: Text('Asset')),
                DropdownMenuItem(value: 'Item', child: Text('Item')),
                DropdownMenuItem(value: 'Serial No', child: Text('Serial No')),
              ],
              onChanged: (v) => setState(() => _doctype = v ?? 'Asset'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: _doctype == 'Item' ? 'Item code' : 'Record name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => widget.onBind(_doctype, _nameCtrl.text),
                icon: const Icon(Icons.link),
                label: const Text('Bind EPC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
