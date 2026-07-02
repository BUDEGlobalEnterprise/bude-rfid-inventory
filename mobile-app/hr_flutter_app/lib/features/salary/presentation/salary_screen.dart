import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/widgets/last_refreshed_label.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/salary_repository.dart';
import 'salary_detail_screen.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final salarySlipsProvider = FutureProvider((ref) {
  return ref.watch(salaryRepositoryProvider).list();
});

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});

  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen> {
  String? _year;
  String? _month;

  @override
  Widget build(BuildContext context) {
    final slips = ref.watch(salarySlipsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary slips')),
      body: slips.when(
        data: (cached) {
          final allRows = cached.data;
          final years = _options(allRows.map((row) => _part(row.startDate, 0)));
          final months = _options(allRows.map((row) => _part(row.startDate, 1)));
          final rows = allRows.where((row) {
            final yearMatches = _year == null || _part(row.startDate, 0) == _year;
            final monthMatches =
                _month == null || _part(row.startDate, 1) == _month;
            return yearMatches && monthMatches;
          }).toList();
          if (rows.isEmpty) {
            return Column(
              children: [
                _SalaryFilters(
                  years: years,
                  months: months,
                  year: _year,
                  month: _month,
                  onYearChanged: (value) => setState(() => _year = value),
                  onMonthChanged: (value) => setState(() => _month = value),
                  onClear: _clearFilters,
                ),
                const Expanded(
                  child: Center(child: Text('No salary slips available.')),
                ),
              ],
            );
          }
          return Column(
            children: [
              _SalaryFilters(
                years: years,
                months: months,
                year: _year,
                month: _month,
                onYearChanged: (value) => setState(() => _year = value),
                onMonthChanged: (value) => setState(() => _month = value),
                onClear: _clearFilters,
              ),
              LastRefreshedLabel(
                fetchedAt: cached.fetchedAt,
                fromCache: cached.fromCache,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(row.name),
                        subtitle: Text('${row.startDate} to ${row.endDate}'),
                        trailing: Text(row.netPay.toString()),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SalaryDetailScreen(name: row.name),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (_, __) => const Center(child: Text('Unable to load salary slips.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _year = null;
      _month = null;
    });
  }

  static String? _part(String value, int index) {
    final parts = value.split('-');
    return parts.length > index && parts[index].isNotEmpty
        ? parts[index]
        : null;
  }

  static List<String> _options(Iterable<String?> values) {
    final rows = values.whereType<String>().toSet().toList()..sort();
    return rows.reversed.toList();
  }
}

class _SalaryFilters extends StatelessWidget {
  const _SalaryFilters({
    required this.years,
    required this.months,
    required this.year,
    required this.month,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onClear,
  });

  final List<String> years;
  final List<String> months;
  final String? year;
  final String? month;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onMonthChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: year,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [
                for (final value in years)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: onYearChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: [
                for (final value in months)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: onMonthChanged,
            ),
          ),
          IconButton(
            tooltip: 'Clear filters',
            onPressed: year == null && month == null ? null : onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
    );
  }
}
