import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_form_providers.dart';

/// Step 1: ask for the registered phone number.
class ForgotPhoneStep extends ConsumerStatefulWidget {
  const ForgotPhoneStep({super.key});

  @override
  ConsumerState<ForgotPhoneStep> createState() => _ForgotPhoneStepState();
}

class _ForgotPhoneStepState extends ConsumerState<ForgotPhoneStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone = TextEditingController(text: ref.read(forgotPasswordProvider).phone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(forgotPasswordProvider.notifier).requestPin(_phone.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.error != null) ...<Widget>[InlineBanner(message: state.error!), const SizedBox(height: 16)],
          HvpTextField(
            label: 'Số điện thoại đã đăng ký',
            controller: _phone,
            prefixIcon: HvpIcons.phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: AuthValidators.phone,
            enabled: !state.submitting,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          HvpButton.primary(label: 'Gửi mã PIN', expand: true, loading: state.submitting, onPressed: _submit),
        ],
      ),
    );
  }
}

/// Step 2: enter the 6-digit PIN. Shows the dev-only banner when the API echoes it.
class ForgotPinStep extends ConsumerStatefulWidget {
  const ForgotPinStep({super.key});

  @override
  ConsumerState<ForgotPinStep> createState() => _ForgotPinStepState();
}

class _ForgotPinStepState extends ConsumerState<ForgotPinStep> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(forgotPasswordProvider.notifier).verifyPin(_pin.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    final notifier = ref.read(forgotPasswordProvider.notifier);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Mã PIN gồm 6 chữ số đã được gửi tới ${state.maskedDestination ?? 'số điện thoại của bạn'}.',
            style: context.txt.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (state.devPin != null) ...<Widget>[
            InlineBanner(
              tone: ChipTone.info,
              title: 'Chỉ dùng khi phát triển',
              message: 'Mã PIN: ${state.devPin}',
              icon: HvpIcons.wrench,
            ),
            const SizedBox(height: 16),
          ],
          if (state.error != null) ...<Widget>[InlineBanner(message: state.error!), const SizedBox(height: 16)],
          HvpTextField(
            label: 'Mã PIN',
            controller: _pin,
            prefixIcon: HvpIcons.key,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            validator: AuthValidators.pin,
            enabled: !state.submitting,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          HvpButton.primary(label: 'Xác nhận', expand: true, loading: state.submitting, onPressed: _submit),
          const SizedBox(height: 8),
          HvpButton.ghost(
            label: 'Gửi lại mã',
            expand: true,
            onPressed: state.submitting ? null : () => notifier.requestPin(state.phone),
          ),
        ],
      ),
    );
  }
}

/// Step 3: choose the new password.
class ForgotResetStep extends ConsumerStatefulWidget {
  const ForgotResetStep({super.key});

  @override
  ConsumerState<ForgotResetStep> createState() => _ForgotResetStepState();
}

class _ForgotResetStepState extends ConsumerState<ForgotResetStep> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(forgotPasswordProvider.notifier).resetPassword(_password.text, _confirm.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.error != null) ...<Widget>[InlineBanner(message: state.error!), const SizedBox(height: 16)],
          HvpTextField(
            label: 'Mật khẩu mới',
            controller: _password,
            prefixIcon: HvpIcons.lockKey,
            obscure: true,
            helper: 'Tối thiểu 6 ký tự, gồm chữ và số.',
            textInputAction: TextInputAction.next,
            validator: AuthValidators.newPassword,
            enabled: !state.submitting,
          ),
          const SizedBox(height: 16),
          HvpTextField(
            label: 'Nhập lại mật khẩu mới',
            controller: _confirm,
            prefixIcon: HvpIcons.lockKey,
            obscure: true,
            textInputAction: TextInputAction.done,
            validator: (v) => AuthValidators.confirmPassword(_password.text, v),
            enabled: !state.submitting,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          HvpButton.primary(label: 'Đặt lại mật khẩu', expand: true, loading: state.submitting, onPressed: _submit),
        ],
      ),
    );
  }
}
