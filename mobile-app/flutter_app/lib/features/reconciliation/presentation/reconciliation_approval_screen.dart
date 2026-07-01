import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/utils/locale_ext.dart';
import '../../audit/domain/audit_operation_summary.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';

class ReconciliationApprovalScreen extends ConsumerStatefulWidget {
  final String opId;
  const ReconciliationApprovalScreen({super.key, required this.opId});

  @override
  ConsumerState<ReconciliationApprovalScreen> createState() =>
      _ReconciliationApprovalScreenState();
}

class _ReconciliationApprovalScreenState
    extends ConsumerState<ReconciliationApprovalScreen> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  String get opId => widget.opId;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = ref.read(syncQueueProvider).getById(opId);
    final summary = op == null ? null : summarizeOperation(op);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.approvalRequired)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.approval_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              summary?.title ?? context.l10n.approvalRequired,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              op == null
                  ? 'Queued operation was not found on this device.'
                  : approvalMessageFor(op),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(
                summary.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            TextField(
              controller: _userCtrl,
              enabled: !_submitting,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Supervisor username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwdCtrl,
              enabled: !_submitting,
              obscureText: true,
              onSubmitted: (_) => _approve(),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Approve as Supervisor'),
              onPressed: _submitting ? null : _approve,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _submitting ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final op = ref.read(syncQueueProvider).getById(opId);
    if (op == null || op.status != OpStatus.pendingApproval) {
      setState(() => _error = 'This operation is no longer awaiting approval.');
      return;
    }

    final user = _userCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (user.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Enter supervisor username and password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).validateSupervisor(
          username: user,
          password: pwd,
        );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() {
          _submitting = false;
          _error = failure.message;
        });
      },
      (data) async {
        final (approvedBy, isSupervisor) = data;
        if (!isSupervisor) {
          setState(() {
            _submitting = false;
            _error = 'User does not have the Stock Manager role.';
          });
          return;
        }
        await ref.read(syncQueueProvider).approve(opId, approvedBy: approvedBy);
        // ignore: discarded_futures
        ref.read(syncEngineProvider).kick();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.approvalGranted)),
        );
        context.pop();
      },
    );
  }
}
