import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/snackbars.dart';
import '../data/salary_repository.dart';
import 'salary_screen.dart';

final salaryDetailProvider =
    FutureProvider.family<SalarySlipDetail, String>((ref, name) {
  return ref.watch(salaryRepositoryProvider).detail(name);
});

class SalaryDetailScreen extends ConsumerWidget {
  const SalaryDetailScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(salaryDetailProvider(name));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary slip'),
        actions: [
          IconButton(
            tooltip: 'Copy PDF link',
            onPressed: () => _copyPdfLink(context, ref),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: detail.when(
        data: (slip) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(slip.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${slip.startDate} to ${slip.endDate}'),
            const SizedBox(height: 20),
            _ComponentSection(title: 'Earnings', rows: slip.earnings),
            _ComponentSection(title: 'Deductions', rows: slip.deductions),
            const Divider(height: 32),
            _TotalRow('Gross pay', slip.grossPay),
            _TotalRow('Total deductions', slip.totalDeduction),
            _TotalRow('Net pay', slip.netPay, emphasize: true),
          ],
        ),
        error: (error, __) {
          final denied =
              error is SalaryAccessException && error.isPermissionDenied;
          return Center(
            child: Text(
              denied
                  ? 'You do not have access to this salary slip.'
                  : 'Unable to load this salary slip.',
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _copyPdfLink(BuildContext context, WidgetRef ref) async {
    try {
      final link = await ref.read(salaryRepositoryProvider).pdfLink(name);
      await Clipboard.setData(ClipboardData(text: link.url));
      if (context.mounted) {
        showSuccessSnackBar(context, 'Salary slip PDF link copied.');
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Unable to prepare salary slip PDF.');
      }
    }
  }
}

class _ComponentSection extends StatelessWidget {
  const _ComponentSection({required this.title, required this.rows});

  final String title;
  final List<SalaryComponent> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row.component),
                Text('${row.amount}'),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount, {this.emphasize = false});

  final String label;
  final num amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$amount', style: style),
        ],
      ),
    );
  }
}
