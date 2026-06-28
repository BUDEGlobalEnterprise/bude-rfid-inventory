import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../data/tracking_remote_data_source.dart';
import '../domain/tracking_allocation.dart';

final trackingRemoteProvider = Provider<TrackingRemoteDataSource>((ref) {
  return TrackingRemoteDataSource(ref.watch(apiClientProvider).dio);
});

class TrackingLineInfo {
  final String itemCode;
  final double qty;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final bool receiptMode;
  final String? warehouse;
  final List<TrackingAllocation> allocations;

  const TrackingLineInfo({
    required this.itemCode,
    required this.qty,
    required this.hasBatchNo,
    required this.hasSerialNo,
    required this.allocations,
    this.receiptMode = false,
    this.warehouse,
  });
}

class TrackingChips extends StatelessWidget {
  final List<TrackingAllocation> allocations;
  const TrackingChips({super.key, required this.allocations});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    for (final allocation in allocations) {
      if (allocation.batchNo?.isNotEmpty == true) {
        chips.add(
          BudeStatusChip(
            label: '${context.l10n.batch}: ${allocation.batchNo}',
            icon: Icons.inventory_outlined,
            color: scheme.primary,
          ),
        );
      }
      if (allocation.expiryDate?.isNotEmpty == true) {
        chips.add(
          BudeStatusChip(
            label: '${context.l10n.expiry}: ${allocation.expiryDate}',
            icon: Icons.event_outlined,
            color: scheme.tertiary,
          ),
        );
      }
      if (allocation.serialNos.isNotEmpty) {
        chips.add(
          BudeStatusChip(
            label: '${context.l10n.serials}: ${allocation.serialNos.length}',
            icon: Icons.confirmation_number_outlined,
            color: scheme.secondary,
          ),
        );
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

Future<List<TrackingAllocation>?> showTrackingAllocationPicker(
  BuildContext context,
  WidgetRef ref,
  TrackingLineInfo info,
) {
  return showDialog<List<TrackingAllocation>>(
    context: context,
    builder: (_) => _TrackingAllocationDialog(info: info),
  );
}

class _TrackingAllocationDialog extends ConsumerStatefulWidget {
  final TrackingLineInfo info;
  const _TrackingAllocationDialog({required this.info});

  @override
  ConsumerState<_TrackingAllocationDialog> createState() =>
      _TrackingAllocationDialogState();
}

class _TrackingAllocationDialogState
    extends ConsumerState<_TrackingAllocationDialog> {
  late final TextEditingController _batchController;
  late final TextEditingController _expiryController;
  late final TextEditingController _serialsController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final first =
        widget.info.allocations.isEmpty ? null : widget.info.allocations.first;
    _batchController = TextEditingController(text: first?.batchNo ?? '');
    _expiryController = TextEditingController(text: first?.expiryDate ?? '');
    _serialsController = TextEditingController(
      text: first?.serialNos.join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    _batchController.dispose();
    _expiryController.dispose();
    _serialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batches = widget.info.hasBatchNo
        ? ref.watch(_batchOptionsProvider(widget.info))
        : const AsyncValue<List<BatchOption>>.data([]);
    final serials = widget.info.hasSerialNo
        ? ref.watch(_serialOptionsProvider(widget.info))
        : const AsyncValue<List<SerialOption>>.data([]);

    return AlertDialog(
      title: Text(context.l10n.tracking),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.info.itemCode),
              if (widget.info.hasBatchNo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _batchController,
                  decoration: InputDecoration(
                    labelText: context.l10n.batch,
                    border: const OutlineInputBorder(),
                    suffixIcon: batches.whenOrNull(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                batches.when(
                  data: (options) => options.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: options.take(8).map((option) {
                              return ActionChip(
                                label: Text(
                                  option.expiryDate == null
                                      ? option.batchNo
                                      : '${option.batchNo} (${option.expiryDate})',
                                ),
                                onPressed: () {
                                  _batchController.text = option.batchNo;
                                  _expiryController.text =
                                      option.expiryDate ?? '';
                                },
                              );
                            }).toList(),
                          ),
                        ),
                  error: (_, __) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                ),
                if (widget.info.receiptMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expiryController,
                    decoration: InputDecoration(
                      labelText: context.l10n.expiry,
                      hintText: 'YYYY-MM-DD',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
              if (widget.info.hasSerialNo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _serialsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: context.l10n.serials,
                    hintText: context.l10n.oneSerialPerLine,
                    border: const OutlineInputBorder(),
                  ),
                ),
                serials.when(
                  data: (options) => options.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: options.take(8).map((option) {
                              return ActionChip(
                                label: Text(option.serialNo),
                                onPressed: () => _appendSerial(option.serialNo),
                              );
                            }).toList(),
                          ),
                        ),
                  error: (_, __) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }

  void _appendSerial(String serialNo) {
    final existing = _serials();
    if (existing.contains(serialNo)) return;
    existing.add(serialNo);
    _serialsController.text = existing.join('\n');
  }

  void _save() {
    final batchNo = _batchController.text.trim();
    final expiryDate = _expiryController.text.trim();
    final serials = _serials();
    if (widget.info.hasBatchNo && batchNo.isEmpty) {
      setState(() => _error = context.l10n.batchRequired);
      return;
    }
    if (widget.info.hasSerialNo && serials.length != widget.info.qty.round()) {
      setState(() => _error = context.l10n.serialCountMustMatchQty);
      return;
    }
    Navigator.of(context).pop([
      TrackingAllocation(
        qty: widget.info.qty,
        batchNo: batchNo.isEmpty ? null : batchNo,
        expiryDate: expiryDate.isEmpty ? null : expiryDate,
        serialNos: serials,
      ),
    ]);
  }

  List<String> _serials() => _serialsController.text
      .split(RegExp(r'[\n,]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

final _batchOptionsProvider = FutureProvider.autoDispose
    .family<List<BatchOption>, TrackingLineInfo>((ref, info) {
  if (info.receiptMode) {
    return Future.value(const []);
  }
  return ref.watch(trackingRemoteProvider).batches(
        info.itemCode,
        warehouse: info.warehouse,
      );
});

final _serialOptionsProvider = FutureProvider.autoDispose
    .family<List<SerialOption>, TrackingLineInfo>((ref, info) {
  if (info.receiptMode) {
    return Future.value(const []);
  }
  return ref.watch(trackingRemoteProvider).serials(
        info.itemCode,
        warehouse: info.warehouse,
        batchNo:
            info.allocations.isEmpty ? null : info.allocations.first.batchNo,
      );
});
