import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/staff_models.dart';
import '../staff_providers.dart';

/// STF-07 administrative staff access controls.
class StaffManageSheet extends ConsumerWidget {
  const StaffManageSheet({super.key, required this.member});
  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(member.fullName,
                  style: context.txt.titleM.copyWith(color: context.hvp.gold)),
              const SizedBox(height: 16),
              _value(context, 'Vai trò', member.roleLabel),
              _value(context, 'Chi nhánh', member.branchName ?? 'Chưa gán'),
              _value(context, 'Trạng thái',
                  StaffStatus.labelOf(member.accountStatus)),
              _value(context, 'Điện thoại', member.phone ?? 'Chưa cập nhật'),
              _value(context, 'Email', member.email ?? 'Chưa cập nhật'),
              _value(
                  context,
                  'Mật khẩu tạm',
                  member.mustChangePassword
                      ? 'Cần đổi ở lần đăng nhập đầu'
                      : 'Không yêu cầu đổi'),
              const SizedBox(height: 20),
              HvpButton.secondary(
                  label: 'Sửa vai trò và chi nhánh',
                  expand: true,
                  onPressed: () => showHvpSheet<void>(context,
                      title: 'Cập nhật nhân sự',
                      builder: (_) => EditStaffSheet(member: member))),
              if (member.accountStatus !=
                  StaffStatus.disabled.wire) ...<Widget>[
                const SizedBox(height: 10),
                HvpButton.danger(
                    label: 'Vô hiệu hoá nhân sự',
                    expand: true,
                    onPressed: () => showHvpSheet<void>(context,
                        title: 'Vô hiệu hoá nhân sự',
                        builder: (_) => DisableStaffSheet(member: member))),
              ],
            ]),
      );

  Widget _value(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(), style: context.txt.label),
              const SizedBox(height: 4),
              SelectableText(value, style: context.txt.body),
            ]),
      );
}

class EditStaffSheet extends ConsumerStatefulWidget {
  const EditStaffSheet({super.key, required this.member});
  final StaffMember member;
  @override
  ConsumerState<EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends ConsumerState<EditStaffSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late StaffRole _role;
  StaffBranch? _branch;
  @override
  void initState() {
    super.initState();
    _role = StaffRole.values.firstWhere(
        (r) => widget.member.roles.contains(r.wire),
        orElse: () => StaffRole.coach);
    Future<void>.microtask(
        () => ref.read(staffUpdateSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false) || _branch == null) {
      setState(() {});
      return;
    }
    final ok = await ref.read(staffUpdateSubmitProvider.notifier).run(() => ref
        .read(staffRepositoryProvider)
        .update(
            widget.member.id,
            UpdateStaffInput(
                role: _role, branchId: _branch!.id, reason: _reason.text)));
    if (!mounted || !ok) return;
    ref.invalidate(staffPageProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(staffBranchesProvider);
    final submit = ref.watch(staffUpdateSubmitProvider);
    return AsyncBody<List<StaffBranch>>(
        value: choices,
        onRetry: () => ref.invalidate(staffBranchesProvider),
        builder: (_, branches) {
          _branch ??=
              branches.where((b) => b.id == widget.member.branchId).firstOrNull;
          return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DropdownButtonFormField<StaffRole>(
                            initialValue: _role,
                            decoration:
                                const InputDecoration(labelText: 'VAI TRÒ'),
                            items: StaffRole.values
                                .map((r) => DropdownMenuItem(
                                    value: r, child: Text(r.label)))
                                .toList(),
                            onChanged: submit.submitting
                                ? null
                                : (v) => setState(() => _role = v!)),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<StaffBranch>(
                            initialValue: _branch,
                            decoration: InputDecoration(
                                labelText: 'CHI NHÁNH',
                                errorText: _branch == null
                                    ? 'Vui lòng chọn chi nhánh.'
                                    : null),
                            items: branches
                                .map((b) => DropdownMenuItem(
                                    value: b, child: Text(b.name)))
                                .toList(),
                            onChanged: submit.submitting
                                ? null
                                : (v) => setState(() => _branch = v)),
                        const SizedBox(height: 14),
                        _ReasonField(
                            controller: _reason, label: 'Lý do thay đổi'),
                        if (submit.error != null) ...<Widget>[
                          const SizedBox(height: 16),
                          InlineBanner(message: submit.error!)
                        ],
                        const SizedBox(height: 24),
                        HvpButton.primary(
                            label: 'Lưu thay đổi',
                            expand: true,
                            loading: submit.submitting,
                            onPressed: submit.submitting ? null : _save),
                      ])));
        });
  }
}

class DisableStaffSheet extends ConsumerStatefulWidget {
  const DisableStaffSheet({super.key, required this.member});
  final StaffMember member;
  @override
  ConsumerState<DisableStaffSheet> createState() => _DisableStaffSheetState();
}

class _DisableStaffSheetState extends ConsumerState<DisableStaffSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(staffStatusSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await ref.read(staffStatusSubmitProvider.notifier).run(() => ref
        .read(staffRepositoryProvider)
        .setStatus(widget.member.id,
            status: StaffStatus.disabled, reason: _reason.text));
    if (!mounted || !ok) return;
    ref.invalidate(staffPageProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(staffStatusSubmitProvider);
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                      'Vô hiệu hoá ${widget.member.fullName}. Người này sẽ bị đăng xuất khỏi các phiên đang hoạt động.',
                      style: context.txt.body),
                  const SizedBox(height: 16),
                  _ReasonField(controller: _reason, label: 'Lý do vô hiệu hoá'),
                  if (submit.error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    InlineBanner(message: submit.error!)
                  ],
                  const SizedBox(height: 24),
                  HvpButton.danger(
                      label: 'Xác nhận vô hiệu hoá',
                      expand: true,
                      loading: submit.submitting,
                      onPressed: submit.submitting ? null : _disable)
                ])));
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => HvpTextField(
      label: label,
      controller: controller,
      maxLines: 3,
      maxLength: 500,
      validator: (v) => (v ?? '').trim().length < 3
          ? 'Vui lòng nhập lý do tối thiểu 3 ký tự.'
          : null);
}
