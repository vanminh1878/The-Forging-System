import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/hvp_toast.dart';
import '../providers/auth_form_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/forgot_steps.dart';

/// Password reset by email PIN: forgot -> verify-pin -> reset.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(forgotPasswordProvider.notifier).reset());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ForgotState>(forgotPasswordProvider, (previous, next) {
      if (previous?.step != ForgotStep.done && next.step == ForgotStep.done) {
        HvpToast.success(context, 'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.');
        context.pop();
      }
    });
    final step = ref.watch(forgotPasswordProvider.select((s) => s.step));
    final (String title, String subtitle, Widget body) = switch (step) {
      ForgotStep.email => ('Quên mật khẩu', 'Nhập email đã đăng ký để nhận mã PIN xác thực.', const ForgotEmailStep()),
      ForgotStep.pin => ('Nhập mã PIN', 'Mã có hiệu lực trong ít phút.', const ForgotPinStep()),
      ForgotStep.reset || ForgotStep.done => (
          'Mật khẩu mới',
          'Đặt mật khẩu mới cho tài khoản của bạn.',
          const ForgotResetStep()
        ),
    };
    return AuthScaffold(title: title, subtitle: subtitle, showBack: true, child: body);
  }
}
