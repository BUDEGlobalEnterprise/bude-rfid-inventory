import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/ui/error_banner.dart';
import '../domain/connection_check_result.dart';
import 'providers/onboarding_notifier.dart';

class CompanySetupScreen extends ConsumerWidget {
  const CompanySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: _Stepper(state: state, notifier: notifier),
                ),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2,
              size: 36,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bude Inventory',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect this device to your ERPNext server.',
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        AppVersion.footer,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Stepper extends ConsumerStatefulWidget {
  final OnboardingState state;
  final OnboardingNotifier notifier;
  const _Stepper({required this.state, required this.notifier});

  @override
  ConsumerState<_Stepper> createState() => _StepperState();
}

class _StepperState extends ConsumerState<_Stepper> {
  @override
  void initState() {
    super.initState();
    // Listen for a clean submit (no error after a submission attempt) and
    // navigate explicitly. The router's refreshListenable should normally
    // handle this, but in flutter web with hash routing there's a one-tick
    // race; pushing here makes the transition deterministic.
    ref.listenManual<OnboardingState>(
      onboardingNotifierProvider,
      (prev, next) {
        final finishedSubmitting = prev?.submitting == true && next.submitting == false;
        if (finishedSubmitting && next.submitError == null) {
          // Successful submit. Wizard cleared the password etc. — push home.
          if (mounted) context.go('/');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = widget.notifier;

    return Stepper(
      type: StepperType.vertical,
      currentStep: state.currentStep,
      onStepTapped: notifier.goToStep,
      onStepContinue: () => _onContinue(state, notifier),
      onStepCancel:
          state.currentStep == 0 ? null : () => notifier.goToStep(state.currentStep - 1),
      controlsBuilder: (context, details) {
        final isLast = state.currentStep == 2;
        final canGo = _canContinue(state);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: canGo ? details.onStepContinue : null,
                child: state.submitting && isLast
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast ? 'Finish setup' : 'Continue'),
              ),
              const SizedBox(width: 12),
              if (details.onStepCancel != null)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Company'),
          subtitle: state.companyName.isEmpty
              ? null
              : Text(state.companyName),
          isActive: state.currentStep >= 0,
          state: state.canAdvanceFromStep1 && state.currentStep > 0
              ? StepState.complete
              : StepState.indexed,
          content: _CompanyStep(state: state, notifier: notifier),
        ),
        Step(
          title: const Text('Server'),
          subtitle: state.lastCheck is ConnectionOk
              ? const Text('Verified')
              : null,
          isActive: state.currentStep >= 1,
          state: state.canAdvanceFromStep2 && state.currentStep > 1
              ? StepState.complete
              : (state.validationStatus == ValidationStatus.error
                  ? StepState.error
                  : StepState.indexed),
          content: _ServerStep(state: state, notifier: notifier),
        ),
        Step(
          title: const Text('Sign in'),
          isActive: state.currentStep >= 2,
          state: state.submitError != null
              ? StepState.error
              : StepState.indexed,
          content: _CredentialsStep(state: state, notifier: notifier),
        ),
      ],
    );
  }

  bool _canContinue(OnboardingState state) {
    return switch (state.currentStep) {
      0 => state.canAdvanceFromStep1,
      1 => state.canAdvanceFromStep2,
      2 => state.canSubmit,
      _ => false,
    };
  }

  Future<void> _onContinue(
    OnboardingState state,
    OnboardingNotifier notifier,
  ) async {
    if (state.currentStep < 2) {
      notifier.goToStep(state.currentStep + 1);
    } else {
      await notifier.submit();
    }
  }
}

class _CompanyStep extends StatelessWidget {
  final OnboardingState state;
  final OnboardingNotifier notifier;
  const _CompanyStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: state.companyName,
      decoration: const InputDecoration(
        labelText: 'Company name',
        hintText: 'e.g. ABC Industries',
        prefixIcon: Icon(Icons.business),
        border: OutlineInputBorder(),
      ),
      onChanged: notifier.setCompanyName,
    );
  }
}

class _ServerStep extends StatelessWidget {
  final OnboardingState state;
  final OnboardingNotifier notifier;
  const _ServerStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isValidating = state.validationStatus == ValidationStatus.validating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: state.erpUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'ERPNext server URL',
            hintText: 'https://erp.example.com',
            prefixIcon: Icon(Icons.public),
            border: OutlineInputBorder(),
          ),
          onChanged: notifier.setErpUrl,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync),
          label: Text(isValidating ? 'Testing…' : 'Test connection'),
          onPressed: isValidating || state.erpUrl.trim().isEmpty
              ? null
              : notifier.testConnection,
        ),
        const SizedBox(height: 12),
        _ValidationStatusBanner(state: state),
      ],
    );
  }
}

class _ValidationStatusBanner extends StatelessWidget {
  final OnboardingState state;
  const _ValidationStatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final check = state.lastCheck;
    if (check == null) return const SizedBox.shrink();
    return switch (check) {
      ConnectionOk(:final erpnextVersion, :final budeApiVersion) => Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 18,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SuccessText(
                'ERPNext $erpnextVersion · bude_api $budeApiVersion',
              ),
            ),
          ],
        ),
      ConnectionUnreachable(:final reason) =>
        ErrorBanner(message: 'Server unreachable: $reason'),
      ConnectionNotErpNext(:final reason) =>
        ErrorBanner(message: 'Not an ERPNext server. $reason'),
      ConnectionBudeApiMissing(:final reason) => ErrorBanner(message: reason),
      ConnectionUnknown(:final reason) => ErrorBanner(message: reason),
    };
  }
}

class _CredentialsStep extends StatelessWidget {
  final OnboardingState state;
  final OnboardingNotifier notifier;
  const _CredentialsStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: state.username,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(
            labelText: 'Username or email',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          onChanged: notifier.setUsername,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
          onChanged: notifier.setPassword,
        ),
        if (state.submitError != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: state.submitError!),
        ],
      ],
    );
  }
}
