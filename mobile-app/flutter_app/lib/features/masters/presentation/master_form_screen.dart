import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/loading_shimmer.dart';
import '../domain/master_def.dart';
import 'providers/masters_providers.dart';

/// Create (recordName == null) or edit a master record. Every input is built
/// from the backend field schema, so this one screen serves all masters.
class MasterFormScreen extends ConsumerWidget {
  final String masterKey;
  final String? recordName;
  const MasterFormScreen({super.key, required this.masterKey, this.recordName});

  MasterDef? _defFrom(List<MasterDef>? list) {
    if (list == null) return null;
    for (final m in list) {
      if (m.key == masterKey) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(mastersCatalogProvider);
    return catalogAsync.when(
      loading: () => const Scaffold(body: ShimmerList(count: 6)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load form: $e')),
      ),
      data: (list) {
        final def = _defFrom(list);
        if (def == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Unknown master.')),
          );
        }
        if (recordName == null) {
          return _MasterForm(def: def, recordName: null, initial: const {});
        }
        final recAsync = ref.watch(
          masterRecordProvider((key: masterKey, name: recordName!)),
        );
        return recAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(def.label)),
            body: const ShimmerList(count: 6),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: Text(def.label)),
            body: Center(child: Text('Failed to load record: $e')),
          ),
          data: (vals) =>
              _MasterForm(def: def, recordName: recordName, initial: vals),
        );
      },
    );
  }
}

class _MasterForm extends ConsumerStatefulWidget {
  final MasterDef def;
  final String? recordName;
  final Map<String, dynamic> initial;
  const _MasterForm({
    required this.def,
    required this.recordName,
    required this.initial,
  });

  @override
  ConsumerState<_MasterForm> createState() => _MasterFormState();
}

class _MasterFormState extends ConsumerState<_MasterForm> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _checks = {};
  final Map<String, String?> _values = {}; // select + link
  bool _submitting = false;

  bool get _isEdit => widget.recordName != null;

  @override
  void initState() {
    super.initState();
    for (final f in widget.def.fields) {
      final init = widget.initial[f.name];
      switch (f.type) {
        case 'check':
          _checks[f.name] = init == 1 || init == true;
          break;
        case 'select':
        case 'link':
          _values[f.name] = init?.toString();
          break;
        default:
          _text[f.name] = TextEditingController(text: init?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(MasterField f) => f.required ? '${f.label} *' : f.label;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _canSubmit() {
    for (final f in widget.def.fields) {
      if (!f.required) continue;
      switch (f.type) {
        case 'check':
          break;
        case 'select':
        case 'link':
          final v = _values[f.name];
          if (v == null || v.isEmpty) return false;
          break;
        default:
          if ((_text[f.name]?.text ?? '').trim().isEmpty) return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _collect() {
    final values = <String, dynamic>{};
    for (final f in widget.def.fields) {
      switch (f.type) {
        case 'check':
          values[f.name] = _checks[f.name] ?? false;
          break;
        case 'number':
          final t = (_text[f.name]?.text ?? '').trim();
          if (t.isNotEmpty) values[f.name] = num.tryParse(t) ?? t;
          break;
        case 'select':
        case 'link':
          final v = _values[f.name];
          if (v != null && v.isNotEmpty) values[f.name] = v;
          break;
        default: // text, date
          final t = (_text[f.name]?.text ?? '').trim();
          if (t.isNotEmpty) values[f.name] = t;
      }
    }
    return values;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final ds = ref.read(mastersDataSourceProvider);
    try {
      if (_isEdit) {
        await ds.update(widget.def.key, widget.recordName!, _collect());
      } else {
        await ds.create(widget.def.key, _collect());
      }
      ref.invalidate(masterRecordsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _field(MasterField f) {
    switch (f.type) {
      case 'check':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _checks[f.name] ?? false,
          onChanged: (v) => setState(() => _checks[f.name] = v),
        );
      case 'select':
        return DropdownButtonFormField<String>(
          initialValue: _values[f.name],
          decoration: InputDecoration(
            labelText: _label(f),
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final o in f.options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => setState(() => _values[f.name] = v),
        );
      case 'link':
        return _LinkField(
          label: _label(f),
          doctype: f.link!,
          initial: _values[f.name],
          onChanged: (v) => setState(() => _values[f.name] = v),
        );
      case 'date':
        return TextField(
          controller: _text[f.name],
          readOnly: true,
          decoration: InputDecoration(
            labelText: _label(f),
            hintText: 'YYYY-MM-DD',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final now = DateTime.now();
            final current = DateTime.tryParse(_text[f.name]?.text ?? '');
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? now,
              firstDate: DateTime(1950),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) {
              _text[f.name]!.text = _fmtDate(picked);
              setState(() {});
            }
          },
        );
      case 'number':
        return TextField(
          controller: _text[f.name],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _label(f),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        );
      default: // text
        return TextField(
          controller: _text[f.name],
          decoration: InputDecoration(
            labelText: _label(f),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _isEdit ? 'Edit ${widget.def.doctype}' : 'New ${widget.def.doctype}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in widget.def.fields) ...[
            _field(f),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _canSubmit() && !_submitting ? _submit : null,
            icon: const Icon(Icons.save),
            label: Text(_submitting ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}

/// Link input backed by `list_link_options` — typeahead search over the target
/// doctype, so large link sets (countries, employees) stay usable.
class _LinkField extends ConsumerWidget {
  final String label;
  final String doctype;
  final String? initial;
  final ValueChanged<String?> onChanged;
  const _LinkField({
    required this.label,
    required this.doctype,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initial ?? ''),
      optionsBuilder: (value) async {
        final q = value.text.trim();
        return ref
            .read(mastersDataSourceProvider)
            .linkOptions(doctype, search: q.isEmpty ? null : q);
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}
