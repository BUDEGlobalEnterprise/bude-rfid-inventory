import 'package:flutter/material.dart';

import '../data/label_generator.dart';
import '../domain/label_request.dart';
import '../domain/label_request_builders.dart';

class LabelScreen extends StatefulWidget {
  final LabelRequest? initialRequest;

  const LabelScreen({super.key, this.initialRequest});

  @override
  State<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  late LabelKind _kind;
  late LabelFormat _format;
  late LabelSize _size;
  late int _quantity;

  final _title = TextEditingController();
  final _primaryCode = TextEditingController();
  final _subtitle = TextEditingController();
  final _uom = TextEditingController();
  final _group = TextEditingController();
  final _warehouse = TextEditingController();
  final _location = TextEditingController();
  final _po = TextEditingController();
  final _lineCount = TextEditingController();
  final _company = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final request = widget.initialRequest ?? palletLabelRequest();
    _applyRequest(request);
  }

  @override
  void dispose() {
    _title.dispose();
    _primaryCode.dispose();
    _subtitle.dispose();
    _uom.dispose();
    _group.dispose();
    _warehouse.dispose();
    _location.dispose();
    _po.dispose();
    _lineCount.dispose();
    _company.dispose();
    super.dispose();
  }

  void _applyRequest(LabelRequest request) {
    _kind = request.kind;
    _format = request.format;
    _size = request.size;
    _quantity = request.quantity;
    _title.text = request.title;
    _primaryCode.text = request.primaryCode;
    _subtitle.text = request.subtitle ?? '';
    _uom.text = request.metadata['UOM'] ?? '';
    _group.text = request.metadata['Group'] ?? '';
    _warehouse.text = request.metadata['Warehouse'] ??
        request.metadata['Target'] ??
        request.metadata['Location'] ??
        '';
    _location.text = request.metadata['Location'] ?? '';
    _po.text = request.metadata['PO'] ?? '';
    _lineCount.text = request.metadata['Lines'] ?? '';
    _company.text = request.metadata['Company'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final request = _currentRequest();

    return Scaffold(
      appBar: AppBar(title: const Text('Label printing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<LabelKind>(
              segments: const [
                ButtonSegment(
                  value: LabelKind.item,
                  label: Text('Item'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: LabelKind.binLocation,
                  label: Text('Bin'),
                  icon: Icon(Icons.warehouse_outlined),
                ),
                ButtonSegment(
                  value: LabelKind.pallet,
                  label: Text('Pallet'),
                  icon: Icon(Icons.view_in_ar_outlined),
                ),
                ButtonSegment(
                  value: LabelKind.receipt,
                  label: Text('Receipt'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _changeKind(value.first),
            ),
          ),
          const SizedBox(height: 18),
          Text('Label size', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<LabelSize>(
              segments: [
                for (final size in LabelSize.values)
                  ButtonSegment(value: size, label: Text(size.displayName)),
              ],
              selected: {_size},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _size = value.first),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<LabelFormat>(
                  segments: const [
                    ButtonSegment(
                      value: LabelFormat.pdf,
                      label: Text('PDF'),
                      icon: Icon(Icons.picture_as_pdf_outlined),
                    ),
                    ButtonSegment(
                      value: LabelFormat.zpl,
                      label: Text('ZPL'),
                      icon: Icon(Icons.description_outlined),
                    ),
                  ],
                  selected: {_format},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _format = value.first),
                ),
              ),
              const SizedBox(width: 12),
              _QuantityStepper(
                value: _quantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFields(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          _LabelPreview(request: request),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_format == LabelFormat.pdf)
                FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text('Preview / print PDF'),
                  onPressed: _busy ? null : () => _run(_printPdf),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(
                  _format == LabelFormat.pdf ? 'Share PDF' : 'Share ZPL',
                ),
                onPressed: _busy ? null : () => _run(_shareCurrent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return switch (_kind) {
      LabelKind.item => Column(
          children: [
            _field(_primaryCode, 'Item code', key: 'label-primary-code-field'),
            _gap,
            _field(_title, 'Item name'),
            _gap,
            _field(_subtitle, 'Description', isRequired: false),
            _gap,
            Row(
              children: [
                Expanded(child: _field(_uom, 'UOM', isRequired: false)),
                const SizedBox(width: 12),
                Expanded(child: _field(_group, 'Group', isRequired: false)),
              ],
            ),
          ],
        ),
      LabelKind.binLocation => Column(
          children: [
            _field(
              _primaryCode,
              'Location name',
              key: 'label-primary-code-field',
            ),
            _gap,
            _field(_warehouse, 'Parent warehouse', isRequired: false),
            _gap,
            _field(_subtitle, 'Description', isRequired: false),
          ],
        ),
      LabelKind.pallet => Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    _primaryCode,
                    'Pallet ID',
                    key: 'label-primary-code-field',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Generate pallet ID',
                  icon: const Icon(Icons.autorenew),
                  onPressed: () => setState(() {
                    _primaryCode.text = generatePalletId();
                  }),
                ),
              ],
            ),
            _gap,
            Row(
              children: [
                Expanded(
                  child: _field(_warehouse, 'Warehouse', isRequired: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_location, 'Location', isRequired: false),
                ),
              ],
            ),
          ],
        ),
      LabelKind.receipt => Column(
          children: [
            _field(
              _primaryCode,
              'Receipt op/server ref',
              key: 'label-primary-code-field',
            ),
            _gap,
            _field(_warehouse, 'Target warehouse', isRequired: false),
            _gap,
            Row(
              children: [
                Expanded(
                  child: _field(
                    _location,
                    'Target location',
                    isRequired: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_po, 'Purchase order', isRequired: false),
                ),
              ],
            ),
            _gap,
            Row(
              children: [
                Expanded(
                  child: _field(_lineCount, 'Line count', isRequired: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_company, 'Company', isRequired: false),
                ),
              ],
            ),
          ],
        ),
    };
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? key,
    bool isRequired = true,
  }) {
    return TextField(
      key: key == null ? null : ValueKey(key),
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() => _error = null),
    );
  }

  LabelRequest _currentRequest() {
    final title = _title.text.trim().isEmpty
        ? _kind.displayName
        : _title.text.trim();
    final primaryCode = _primaryCode.text.trim();
    final subtitle = switch (_kind) {
      LabelKind.pallet => _firstNonEmpty([_location.text, _warehouse.text]),
      LabelKind.receipt => _firstNonEmpty([_location.text, _warehouse.text]),
      _ => _subtitle.text.trim(),
    };

    return LabelRequest(
      kind: _kind,
      format: _format,
      size: _size,
      title: title,
      primaryCode: primaryCode,
      subtitle: subtitle.isEmpty ? null : subtitle,
      quantity: _quantity,
      receiptOpId: _kind == LabelKind.receipt ? primaryCode : null,
      receiptPayload: _kind == LabelKind.receipt
          ? {
              'op_id': primaryCode,
              if (_warehouse.text.trim().isNotEmpty)
                'target_warehouse': _warehouse.text.trim(),
              if (_location.text.trim().isNotEmpty)
                'target_location': _location.text.trim(),
              if (_po.text.trim().isNotEmpty) 'against_po': _po.text.trim(),
              if (_lineCount.text.trim().isNotEmpty)
                'line_count': _lineCount.text.trim(),
            }
          : null,
      metadata: switch (_kind) {
        LabelKind.item => {
            if (_uom.text.trim().isNotEmpty) 'UOM': _uom.text.trim(),
            if (_group.text.trim().isNotEmpty) 'Group': _group.text.trim(),
          },
        LabelKind.binLocation => {
            if (_warehouse.text.trim().isNotEmpty)
              'Warehouse': _warehouse.text.trim(),
          },
        LabelKind.pallet => {
            if (_warehouse.text.trim().isNotEmpty)
              'Warehouse': _warehouse.text.trim(),
            if (_location.text.trim().isNotEmpty)
              'Location': _location.text.trim(),
          },
        LabelKind.receipt => {
            if (_warehouse.text.trim().isNotEmpty)
              'Target': _warehouse.text.trim(),
            if (_location.text.trim().isNotEmpty)
              'Location': _location.text.trim(),
            if (_po.text.trim().isNotEmpty) 'PO': _po.text.trim(),
            if (_lineCount.text.trim().isNotEmpty)
              'Lines': _lineCount.text.trim(),
            if (_company.text.trim().isNotEmpty)
              'Company': _company.text.trim(),
          },
      },
    );
  }

  void _changeKind(LabelKind kind) {
    setState(() {
      _kind = kind;
      _error = null;
      if (kind == LabelKind.pallet && _primaryCode.text.trim().isEmpty) {
        _primaryCode.text = generatePalletId();
      }
      if (_title.text.trim().isEmpty || widget.initialRequest == null) {
        _title.text =
            kind == LabelKind.receipt ? 'Goods receipt' : kind.displayName;
      }
    });
  }

  Future<void> _run(Future<void> Function(LabelRequest request) action) async {
    final request = _currentRequest();
    final error = validateLabelRequest(request);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label export ready.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not generate label: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPdf(LabelRequest request) => LabelGenerator.printPdf(
        request.copyWith(format: LabelFormat.pdf),
      );

  Future<void> _shareCurrent(LabelRequest request) {
    return request.format == LabelFormat.pdf
        ? LabelGenerator.sharePdf(request)
        : LabelGenerator.shareZpl(request);
  }
}

const _gap = SizedBox(height: 12);

class _QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'Decrease quantity',
            icon: const Icon(Icons.remove),
            onPressed: () => onChanged(value - 1),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton.outlined(
            tooltip: 'Increase quantity',
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _LabelPreview extends StatelessWidget {
  final LabelRequest request;

  const _LabelPreview({required this.request});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.usesQr ? Icons.qr_code_2 : Icons.qr_code_scanner,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${request.kind.displayName} preview',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(request.size.displayName),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              request.primaryCode.isEmpty
                  ? 'No code entered'
                  : request.primaryCode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if ((request.subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(request.subtitle!),
            ],
            if (request.metadata.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in request.metadata.entries)
                    Chip(
                      label: Text('${entry.key}: ${entry.value}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${request.format.displayName} x ${request.quantity}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
