import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../auth/domain/auth_validators.dart';
import '../../domain/staff_models.dart';
import '../staff_providers.dart';

/// STF-06: form that creates a staff account and exposes its one-time password.
class CreateStaffSheet extends ConsumerStatefulWidget {
  const CreateStaffSheet({super.key});

  @override
  ConsumerState<CreateStaffSheet> createState() => _CreateStaffSheetState();
}

class _CreateStaffSheetState extends ConsumerState<CreateStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  StaffRole _role = StaffRole.coach;
  StaffBranch? _branch;
  bool _showContactError = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(createStaffSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hasContact =
        _phone.text.trim().isNotEmpty || _email.text.trim().isNotEmpty;
    if (!(_formKey.currentState?.validate() ?? false) ||
        _branch == null ||
        !hasContact) {
      setState(() => _showContactError = !hasContact);
      return;
    }
    final input = CreateStaffInput(
      fullName: _name.text,
      phone: _phone.text.trim().isEmpty ? null : _phone.text,
      email: _email.text.trim().isEmpty ? null : _email.text,
      role: _role,
      branchId: _branch!.id,
    );
    CreatedStaff? created;
    final ok = await ref.read(createStaffSubmitProvider.notifier).run(() async {
      created = await ref.read(staffRepositoryProvider).create(input);
    });
    if (!mounted || !ok || created == null) return;
    ref.invalidate(staffPageProvider);
    await showHvpSheet<void>(context,
        title: 'Tạo nhân sự thành công',
        builder: (_) => _TemporaryPasswordResult(created: created!));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(staffBranchesProvider);
    final submit = ref.watch(createStaffSubmitProvider);
    return AsyncBody<List<StaffBranch>>(
      value: branches,
      onRetry: () => ref.invalidate(staffBranchesProvider),
      builder: (_, choices) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Tạo tài khoản nhân sự và cấp mật khẩu tạm dùng một lần.',
                    style: context.txt.bodySmall),
                const SizedBox(height: 16),
                HvpTextField(
                    label: 'Họ và tên',
                    controller: _name,
                    maxLength: 100,
                    validator: AuthValidators.fullName,
                    textInputAction: TextInputAction.next),
                const SizedBox(height: 14),
                HvpTextField(
                    label: 'Số điện thoại',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 16,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value!.trim().isEmpty
                        ? null
                        : (AuthValidators.isPhone(value)
                            ? null
                            : 'Số điện thoại chưa hợp lệ.')),
                const SizedBox(height: 14),
                HvpTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 254,
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.optionalEmail),
                if (_showContactError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Vui lòng nhập số điện thoại hoặc email.',
                        style: context.txt.bodySmall
                            .copyWith(color: context.hvp.red)),
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<StaffRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'VAI TRO'),
                  items: StaffRole.values
                      .map((role) => DropdownMenuItem(
                          value: role, child: Text(role.label)))
                      .toList(),
                  onChanged: submit.submitting
                      ? null
                      : (value) => setState(() => _role = value!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<StaffBranch>(
                  initialValue: _branch,
                  decoration: InputDecoration(
                      labelText: 'CHI NHÁNH',
                      errorText:
                          _branch == null ? 'Vui lòng chọn chi nhánh.' : null),
                  items: choices
                      .map((branch) => DropdownMenuItem(
                          value: branch, child: Text(branch.name)))
                      .toList(),
                  onChanged: submit.submitting
                      ? null
                      : (value) => setState(() => _branch = value),
                ),
                if (submit.error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  InlineBanner(message: submit.error!)
                ],
                const SizedBox(height: 24),
                HvpButton.primary(
                    label: 'Tạo nhân sự',
                    expand: true,
                    loading: submit.submitting,
                    onPressed: submit.submitting ? null : _submit),
              ]),
        ),
      ),
    );
  }
}

class _TemporaryPasswordResult extends StatelessWidget {
  const _TemporaryPasswordResult({required this.created});
  final CreatedStaff created;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                  '${created.staff.fullName} phải đổi mật khẩu ở lần đăng nhập đầu tiên.',
                  style: context.txt.body),
              const SizedBox(height: 16),
              SelectableText(created.temporaryPassword,
                  style: context.txt.titleM.copyWith(color: context.hvp.gold)),
              const SizedBox(height: 8),
              Text(
                  'Sao chép và gửi mật khẩu này an toàn. Mật khẩu sẽ không hiện lại.',
                  style: context.txt.bodySmall),
              const SizedBox(height: 20),
              HvpButton.primary(
                  label: 'Đã lưu mật khẩu',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop()),
            ]),
      );
}
