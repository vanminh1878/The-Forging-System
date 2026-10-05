import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_form_providers.dart';
import '../widgets/auth_scaffold.dart';

/// New member registration. The branch can be chosen later in the profile
/// because the branch directory requires a signed-in user.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(registerSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = RegisterInput(
      fullName: _name.text,
      phone: _phone.text,
      email: _email.text,
      password: _password.text,
    );
    await ref.read(registerSubmitProvider.notifier).run(
          () => ref.read(authControllerProvider.notifier).register(input),
        );
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(registerSubmitProvider);
    final enabled = !submit.submitting;
    return AuthScaffold(
      title: 'Tạo tài khoản',
      subtitle: 'Một tài khoản dùng chung cho mọi chi nhánh HVP.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (submit.error != null) ...<Widget>[
              InlineBanner(message: submit.error!),
              const SizedBox(height: 16),
            ],
            HvpTextField(
              label: 'Họ và tên',
              controller: _name,
              prefixIcon: HvpIcons.idCard,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              validator: AuthValidators.fullName,
              enabled: enabled,
            ),
            const SizedBox(height: 16),
            HvpTextField(
              label: 'Số điện thoại',
              controller: _phone,
              prefixIcon: HvpIcons.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              validator: AuthValidators.phone,
              enabled: enabled,
            ),
            const SizedBox(height: 16),
            HvpTextField(
              label: 'Email (không bắt buộc)',
              controller: _email,
              prefixIcon: HvpIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              validator: AuthValidators.optionalEmail,
              enabled: enabled,
            ),
            const SizedBox(height: 16),
            HvpTextField(
              label: 'Mật khẩu',
              controller: _password,
              prefixIcon: HvpIcons.lockKey,
              obscure: true,
              helper: 'Tối thiểu 6 ký tự, gồm chữ và số.',
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              validator: AuthValidators.newPassword,
              enabled: enabled,
              inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(72)],
            ),
            const SizedBox(height: 16),
            HvpTextField(
              label: 'Nhập lại mật khẩu',
              controller: _confirm,
              prefixIcon: HvpIcons.lockKey,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (v) => AuthValidators.confirmPassword(_password.text, v),
              enabled: enabled,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            HvpButton.primary(label: 'Đăng ký', expand: true, loading: submit.submitting, onPressed: _submit),
            const SizedBox(height: 8),
            HvpButton.ghost(
              label: 'Đã có tài khoản? Đăng nhập',
              expand: true,
              onPressed: enabled ? () => context.pop() : null,
            ),
          ],
        ),
      ),
    );
  }
}
