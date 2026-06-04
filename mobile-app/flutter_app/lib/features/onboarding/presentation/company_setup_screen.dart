import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/connection_check_result.dart';
import 'providers/onboarding_notifier.dart';

class CompanySetupScreen extends ConsumerWidget {
  const CompanySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your workspace')),
      body: Stepper(
        currentStep: state.currentStep,
        onStepTapped: notifier.goToStep,
        onStepContinue: () => _onContinue(context, ref, state, notifier),
        onStepCancel:
            state.currentStep == 0 ? null : () => notifier.goToStep(state.currentStep - 1),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _canContinue(state) ? details.onStepContinue : null,
                  child: Text(state.currentStep == 2 ? 'Finish' : 'Continue'),
                ),
                const SizedBox(width: 8),
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
            isActive: state.currentStep >= 0,
            content: _CompanyStep(state: state, notifier: notifier),
          ),
          Step(
            title: const Text('Server'),
            isActive: state.currentStep >= 1,
            content: _ServerStep(state: state, notifier: notifier),
          ),
          Step(
            title: const Text('Sign in'),
            isActive: state.currentStep >= 2,
            content: _CredentialsStep(state: state, notifier: notifier),
          ),
        ],
      ),
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
    BuildContext context,
    WidgetRef ref,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: state.erpUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'ERP URL',
            hintText: 'https://erp.example.com',
            border: OutlineInputBorder(),
          ),
          onChanged: notifier.setErpUrl,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              icon: state.validationStatus == ValidationStatus.validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync),
              label: const Text('Test connection'),
              onPressed: state.validationStatus == ValidationStatus.validating ||
                      state.erpUrl.trim().isEmpty
                  ? null
                  : notifier.testConnection,
            ),
            const SizedBox(width: 12),
            Expanded(child: _ValidationStatusBanner(state: state)),
          ],
        ),
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
      ConnectionOk(:final erpnextVersion, :final budeApiVersion) => Text(
          'ERPNext $erpnextVersion · bude_api $budeApiVersion',
          style: TextStyle(color: Colors.green.shade800),
        ),
      ConnectionUnreachable(:final reason) =>
        _ErrorText('Unreachable: $reason'),
      ConnectionNotErpNext(:final reason) =>
        _ErrorText('Not an ERPNext server: $reason'),
      ConnectionBudeApiMissing(:final reason) => _ErrorText(reason),
      ConnectionUnknown(:final reason) => _ErrorText(reason),
    };
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Colors.red.shade800),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
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
            border: OutlineInputBorder(),
          ),
          onChanged: notifier.setPassword,
        ),
        if (state.submitError != null) ...[
          const SizedBox(height: 12),
          _ErrorText(state.submitError!),
        ],
      ],
    );
  }
}
