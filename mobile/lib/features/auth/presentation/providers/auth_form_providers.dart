import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/state/submit_notifier.dart';
import 'auth_providers.dart';

final loginSubmitProvider = NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
final registerSubmitProvider = NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

enum ForgotStep { phone, pin, reset, done }

class ForgotState {
  const ForgotState({
    this.step = ForgotStep.phone,
    this.phone = '',
    this.requestId,
    this.maskedDestination,
    this.devPin,
    this.resetToken,
    this.submitting = false,
    this.error,
  });

  final ForgotStep step;
  final String phone;
  final String? requestId;
  final String? maskedDestination;

  /// Development only: PIN echoed by the API.
  final String? devPin;
  final String? resetToken;
  final bool submitting;
  final String? error;

  ForgotState copyWith({
    ForgotStep? step,
    String? phone,
    String? requestId,
    String? maskedDestination,
    String? devPin,
    String? resetToken,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      ForgotState(
        step: step ?? this.step,
        phone: phone ?? this.phone,
        requestId: requestId ?? this.requestId,
        maskedDestination: maskedDestination ?? this.maskedDestination,
        devPin: devPin ?? this.devPin,
        resetToken: resetToken ?? this.resetToken,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Three-step password reset: phone -> PIN -> new password.
class ForgotPasswordController extends Notifier<ForgotState> {
  @override
  ForgotState build() => const ForgotState();

  void reset() => state = const ForgotState();

  Future<void> requestPin(String phone) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final ticket = await ref.read(authRepositoryProvider).requestPasswordReset(phone);
      state = ForgotState(
        step: ForgotStep.pin,
        phone: phone,
        requestId: ticket.requestId,
        maskedDestination: ticket.maskedDestination,
        devPin: ticket.devPin,
      );
    } catch (e) {
      state = state.copyWith(submitting: false, error: errorMessage(e));
    }
  }

  Future<void> verifyPin(String pin) async {
    final requestId = state.requestId;
    if (requestId == null) return;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final token = await ref.read(authRepositoryProvider).verifyResetPin(requestId: requestId, pin: pin);
      state = state.copyWith(step: ForgotStep.reset, resetToken: token, submitting: false);
    } catch (e) {
      state = state.copyWith(submitting: false, error: errorMessage(e));
    }
  }

  Future<void> resetPassword(String password, String confirm) async {
    final requestId = state.requestId;
    final token = state.resetToken;
    if (requestId == null || token == null) return;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            requestId: requestId,
            resetToken: token,
            password: password,
            passwordConfirm: confirm,
          );
      state = state.copyWith(step: ForgotStep.done, submitting: false);
    } catch (e) {
      state = state.copyWith(submitting: false, error: errorMessage(e));
    }
  }
}

final forgotPasswordProvider = NotifierProvider<ForgotPasswordController, ForgotState>(ForgotPasswordController.new);
