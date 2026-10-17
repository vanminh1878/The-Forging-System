import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_form_providers.dart';
import '../providers/auth_providers.dart';
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
  final _otp = TextEditingController();

  /// Set after the OTP was sent (phase 2); cleared when the email text changes.
  OtpTicket? _ticket;
  String _ticketEmail = '';

  @override
  void initState() {
    super.initState();
    // The controller also notifies on cursor moves, so compare the text itself.
    _email.addListener(() {
      if (_ticket != null && _email.text != _ticketEmail) setState(() => _ticket = null);
    });
    Future<void>.microtask(() => ref.read(registerSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    OtpTicket? ticket;
    final email = _email.text;
    final ok = await ref.read(registerSubmitProvider.notifier).run(() async {
      ticket = await ref.read(authRepositoryProvider).requestRegisterOtp(email);
    });
    if (!mounted || !ok) return;
    setState(() {
      _ticket = ticket;
      _ticketEmail = email;
      _otp.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ticket = _ticket;
    if (ticket == null) return _requestOtp();
    final input = RegisterInput(
      fullName: _name.text,
      phone: _phone.text,
      email: _email.text,
      password: _password.text,
      otpRequestId: ticket.requestId,
      otp: _otp.text,
    );
    await ref.read(registerSubmitProvider.notifier).run(
          () => ref.read(authControllerProvider.notifier).register(input),
        );
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(registerSubmitProvider);
    final enabled = !submit.submitting;
    final ticket = _ticket;
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
              label: 'Email',
              controller: _email,
              prefixIcon: HvpIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              validator: AuthValidators.email,
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
              textInputAction: ticket == null ? TextInputAction.done : TextInputAction.next,
              validator: (v) => AuthValidators.confirmPassword(_password.text, v),
              enabled: enabled,
              onSubmitted: ticket == null ? (_) => _submit() : null,
            ),
            if (ticket != null) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Mã xác thực đã gửi tới ${ticket.maskedDestination}',
                style: context.txt.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (ticket.devPin != null) ...<Widget>[
                InlineBanner(
                  tone: ChipTone.info,
                  title: 'Chỉ dùng khi phát triển',
                  message: 'Mã PIN: ${ticket.devPin}',
                  icon: HvpIcons.wrench,
                ),
                const SizedBox(height: 16),
              ],
              HvpTextField(
                label: 'Mã xác thực',
                controller: _otp,
                prefixIcon: HvpIcons.key,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                validator: AuthValidators.pin,
                enabled: enabled,
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 24),
            HvpButton.primary(
              label: ticket == null ? 'Đăng ký' : 'Xác nhận & đăng ký',
              expand: true,
              loading: submit.submitting,
              onPressed: _submit,
            ),
            if (ticket != null) ...<Widget>[
              const SizedBox(height: 8),
              HvpButton.ghost(label: 'Gửi lại mã', expand: true, onPressed: enabled ? _requestOtp : null),
            ],
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
