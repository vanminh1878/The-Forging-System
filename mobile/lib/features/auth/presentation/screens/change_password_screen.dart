import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_form_providers.dart';
import '../widgets/auth_scaffold.dart';

/// STF-08 mandatory first-login password replacement.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(changePasswordSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await ref.read(changePasswordSubmitProvider.notifier).run(() => ref
        .read(authControllerProvider.notifier)
        .changeTemporaryPassword(
            currentPassword: _current.text,
            password: _password.text,
            passwordConfirm: _confirm.text));
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(changePasswordSubmitProvider);
    return AuthScaffold(
        title: 'Đổi mật khẩu',
        subtitle: 'Bạn phải thay mật khẩu tạm trước khi tiếp tục.',
        child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (submit.error != null) ...<Widget>[
                    InlineBanner(message: submit.error!),
                    const SizedBox(height: 16)
                  ],
                  HvpTextField(
                      label: 'Mật khẩu tạm',
                      controller: _current,
                      obscure: true,
                      validator: AuthValidators.loginPassword,
                      enabled: !submit.submitting),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Mật khẩu mới',
                      controller: _password,
                      obscure: true,
                      helper: 'Tối thiểu 8 ký tự, gồm chữ và số.',
                      validator: (v) =>
                          AuthValidators.newPassword(v, minLength: 8),
                      enabled: !submit.submitting),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Nhập lại mật khẩu mới',
                      controller: _confirm,
                      obscure: true,
                      validator: (v) =>
                          AuthValidators.confirmPassword(_password.text, v),
                      enabled: !submit.submitting,
                      onSubmitted: (_) => _submit()),
                  const SizedBox(height: 24),
                  HvpButton.primary(
                      label: 'Đổi mật khẩu',
                      expand: true,
                      loading: submit.submitting,
                      onPressed: submit.submitting ? null : _submit)
                ])));
  }
}
