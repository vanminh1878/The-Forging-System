import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/api_exception.dart';
import '../error/error_mapper.dart';

/// State of a form submission (submitting flag, error banner, per-field errors).
class SubmitState {
  const SubmitState({this.submitting = false, this.error, this.fieldErrors = const <String, String>{}});

  final bool submitting;
  final String? error;
  final Map<String, String> fieldErrors;
}

/// Runs a submit action and exposes progress/errors to the form.
/// Register one provider per form: `NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new)`.
class SubmitNotifier extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Returns true when [action] completed without error.
  Future<bool> run(Future<void> Function() action) async {
    state = const SubmitState(submitting: true);
    try {
      await action();
      state = const SubmitState();
      return true;
    } on ApiException catch (e) {
      state = SubmitState(error: e.message, fieldErrors: e.fieldErrors);
      return false;
    } catch (e) {
      state = SubmitState(error: errorMessage(e));
      return false;
    }
  }

  void reset() => state = const SubmitState();
}
