import 'package:flutter/material.dart';

/// Labelled section divider used in the settings screen and elsewhere.
class BudeSectionHeader extends StatelessWidget {
  final String title;
  const BudeSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: scheme.primary,
        ),
      ),
    );
  }
}
