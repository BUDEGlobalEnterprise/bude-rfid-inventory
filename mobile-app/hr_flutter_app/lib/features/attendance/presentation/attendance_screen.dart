import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_controller.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceControllerProvider);
    final checkedIn = state.status?.checkedIn ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checkedIn ? 'Checked in' : 'Not checked in',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Pending offline records: ${state.pendingCount}'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: checkedIn
                              ? null
                              : () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .check('IN'),
                          icon: const Icon(Icons.login),
                          label: const Text('Check in'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: checkedIn
                              ? () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .check('OUT')
                              : null,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
