import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/error_banner.dart';
import '../../../../core/utils/locale_ext.dart';
import '../providers/transfer_providers.dart';

class WarehouseLocationDropdown extends ConsumerWidget {
  final String label;
  final String warehouse;
  final String? value;
  final String? helperText;
  final ValueChanged<String?> onChanged;

  const WarehouseLocationDropdown({
    super.key,
    required this.label,
    required this.warehouse,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(warehouseLocationsProvider(warehouse));
    return locationsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorText(e.toString()),
      data: (locations) {
        if (value != null && !locations.contains(value)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(null));
        }
        if (locations.isEmpty) return const SizedBox.shrink();

        final effectiveValue = locations.contains(value) ? value : null;
        return DropdownButtonFormField<String>(
          key: ValueKey('$label-$warehouse-$effectiveValue'),
          initialValue: effectiveValue,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.l10n.noneSelected),
            ),
            ...locations.map(
              (location) => DropdownMenuItem(
                value: location,
                child: Text(location),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
