import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../tenant/presentation/providers/tenant_notifier.dart';
import '../../data/connection_validator_impl.dart';
import '../../domain/connection_check_result.dart';
import '../../domain/connection_validator.dart';

enum ValidationStatus { idle, validating, ok, error }

class OnboardingState extends Equatable {
  final String companyName;
  final String erpUrl;
  final String username;
  final String password;
  final int currentStep;
  final ValidationStatus validationStatus;
  final ConnectionCheckResult? lastCheck;
  final bool submitting;
  final String? submitError;

  const OnboardingState({
    this.companyName = '',
    this.erpUrl = '',
    this.username = '',
    this.password = '',
    this.currentStep = 0,
    this.validationStatus = ValidationStatus.idle,
    this.lastCheck,
    this.submitting = false,
    this.submitError,
  });

  OnboardingState copyWith({
    String? companyName,
    String? erpUrl,
    String? username,
    String? password,
    int? currentStep,
    ValidationStatus? validationStatus,
    ConnectionCheckResult? lastCheck,
    bool? submitting,
    String? submitError,
    bool clearLastCheck = false,
    bool clearSubmitError = false,
  }) {
    return OnboardingState(
      companyName: companyName ?? this.companyName,
      erpUrl: erpUrl ?? this.erpUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      currentStep: currentStep ?? this.currentStep,
      validationStatus: validationStatus ?? this.validationStatus,
      lastCheck: clearLastCheck ? null : (lastCheck ?? this.lastCheck),
      submitting: submitting ?? this.submitting,
      submitError:
          clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  bool get canAdvanceFromStep1 => companyName.trim().isNotEmpty;
  bool get canAdvanceFromStep2 =>
      validationStatus == ValidationStatus.ok && lastCheck is ConnectionOk;
  bool get canSubmit =>
      canAdvanceFromStep2 &&
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      !submitting;

  @override
  List<Object?> get props => [
        companyName,
        erpUrl,
        username,
        password,
        currentStep,
        validationStatus,
        lastCheck,
        submitting,
        submitError,
      ];
}

/// Final-step callback. Slice A leaves this as a no-op so the wizard can be
/// previewed; Slice B will replace it with persistence + login.
typedef OnOnboardingComplete = Future<String?> Function({
  required String companyName,
  required String erpUrl,
  required String username,
  required String password,
  required ConnectionOk check,
});

final connectionValidatorProvider = Provider<ConnectionValidator>(
  (ref) => ConnectionValidatorImpl(),
);

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(
    validator: ref.watch(connectionValidatorProvider),
    onComplete: ({
      required companyName,
      required erpUrl,
      required username,
      required password,
      required check,
    }) async {
      // Persist tenant first so AppConfig + ApiClient point at the chosen URL
      // before the auth request fires.
      await ref.read(tenantNotifierProvider.notifier).createAndActivate(
            companyName: companyName,
            erpUrl: erpUrl,
          );
      await ref.read(authNotifierProvider.notifier).login(username, password);

      final auth = ref.read(authNotifierProvider);
      if (auth is AuthFailed) return auth.message;
      return null;
    },
  );
});

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final ConnectionValidator validator;
  final OnOnboardingComplete onComplete;

  OnboardingNotifier({required this.validator, required this.onComplete})
      : super(const OnboardingState());

  void setCompanyName(String v) =>
      state = state.copyWith(companyName: v, clearSubmitError: true);

  void setErpUrl(String v) => state = state.copyWith(
        erpUrl: v,
        // A fresh URL invalidates any previous check.
        validationStatus: ValidationStatus.idle,
        clearLastCheck: true,
        clearSubmitError: true,
      );

  void setUsername(String v) =>
      state = state.copyWith(username: v, clearSubmitError: true);

  void setPassword(String v) =>
      state = state.copyWith(password: v, clearSubmitError: true);

  void goToStep(int step) {
    if (step < 0 || step > 2) return;
    state = state.copyWith(currentStep: step);
  }

  Future<void> testConnection() async {
    if (state.erpUrl.trim().isEmpty) return;
    state = state.copyWith(
      validationStatus: ValidationStatus.validating,
      clearLastCheck: true,
    );
    final result = await validator.check(state.erpUrl);
    state = state.copyWith(
      validationStatus: result is ConnectionOk
          ? ValidationStatus.ok
          : ValidationStatus.error,
      lastCheck: result,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final check = state.lastCheck;
    if (check is! ConnectionOk) return;

    state = state.copyWith(submitting: true, clearSubmitError: true);
    final error = await onComplete(
      companyName: state.companyName.trim(),
      erpUrl: state.erpUrl.trim(),
      username: state.username.trim(),
      password: state.password,
      check: check,
    );
    state = state.copyWith(
      submitting: false,
      submitError: error,
    );
  }
}
