import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_form_providers.dart';
import '../widgets/auth_scaffold.dart';

/// Email-or-phone + password sign in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(loginSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(loginSubmitProvider.notifier).run(
          () => ref.read(authControllerProvider.notifier).login(
                identifier: _identifier.text,
                password: _password.text,
              ),
        );
    // On success the router redirects to the role home; nothing else to do.
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(loginSubmitProvider);
    final notice = ref.watch(authControllerProvider.select((s) => s.notice));
    return AuthScaffold(
      title: 'Đăng nhập',
      spotlightTitle: true,
      subtitle: 'Dùng email hoặc số điện thoại đã đăng ký.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (notice != null && submit.error == null) ...<Widget>[
                InlineBanner(message: notice, tone: ChipTone.warning),
                const SizedBox(height: 16),
              ],
              if (submit.error != null) ...<Widget>[
                InlineBanner(message: submit.error!),
                const SizedBox(height: 16),
              ],
              HvpTextField(
                label: 'Email hoặc số điện thoại',
                controller: _identifier,
                prefixIcon: HvpIcons.user,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.username],
                validator: AuthValidators.identifier,
                enabled: !submit.submitting,
              ),
              const SizedBox(height: 16),
              HvpTextField(
                label: 'Mật khẩu',
                controller: _password,
                prefixIcon: HvpIcons.lockKey,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                validator: AuthValidators.loginPassword,
                enabled: !submit.submitting,
                onSubmitted: (_) => _submit(),
                inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(72)],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: submit.submitting ? null : () => context.push(AppPaths.forgotPassword),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              const SizedBox(height: 8),
              HvpButton.primary(label: 'Đăng nhập', expand: true, loading: submit.submitting, onPressed: _submit),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 16),
              HvpButton.ghost(
                label: 'Tạo tài khoản mới',
                expand: true,
                onPressed: submit.submitting ? null : () => context.push(AppPaths.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "—— HOẶC ——" separator between the primary and the secondary action.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final line = Expanded(child: Container(height: 1, color: c.borderStrong));
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('HOẶC', style: context.txt.label.copyWith(color: c.textMuted, letterSpacing: 3.2, fontSize: 11)),
          ),
          line,
        ],
      ),
    );
  }
}
