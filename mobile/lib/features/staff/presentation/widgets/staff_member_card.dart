import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/staff_models.dart';

class StaffMemberCard extends StatelessWidget {
  const StaffMemberCard({super.key, required this.member});
  final StaffMember member;

  @override
  Widget build(BuildContext context) => HvpCard(
        padding: const EdgeInsets.all(12),
        cut: 8,
        onTap: () => showHvpSheet<void>(context,
            title: 'Hồ sơ nhân sự',
            builder: (_) => _StaffDetails(member: member)),
        child: Row(children: <Widget>[
          HvpAvatar(name: member.fullName, size: 38),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(member.fullName,
                    style:
                        context.txt.titleS.copyWith(color: context.hvp.gold)),
                const SizedBox(height: 4),
                Text(member.roleLabel, style: context.txt.bodySmall),
                Text(member.branchName ?? 'Chưa gán chi nhánh',
                    style: context.txt.caption),
                const SizedBox(height: 8),
                StatusChip(
                    label: StaffStatus.labelOf(member.accountStatus),
                    tone: _tone(member.accountStatus)),
              ])),
          Icon(HvpIcons.caretRight, color: context.hvp.textMuted, size: 20),
        ]),
      );
}

ChipTone _tone(String status) => switch (status) {
      'ACTIVE' => ChipTone.success,
      'LOCKED' => ChipTone.warning,
      'DISABLED' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

class _StaffDetails extends StatelessWidget {
  const _StaffDetails({required this.member});
  final StaffMember member;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(children: <Widget>[
                HvpAvatar(name: member.fullName),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(member.fullName,
                        style: context.txt.titleM
                            .copyWith(color: context.hvp.gold))),
              ]),
              const SizedBox(height: 20),
              _line(context, 'Vai trò', member.roleLabel),
              _line(context, 'Chi nhánh', member.branchName ?? 'Chưa gán'),
              _line(context, 'Trạng thái',
                  StaffStatus.labelOf(member.accountStatus)),
              _line(context, 'Điện thoại', member.phone ?? 'Chưa cập nhật'),
              _line(context, 'Email', member.email ?? 'Chưa cập nhật'),
              _line(
                  context,
                  'Mật khẩu tạm',
                  member.mustChangePassword
                      ? 'Cần đổi ở lần đăng nhập đầu'
                      : 'Không yêu cầu đổi'),
            ]),
      );

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(), style: context.txt.label),
              const SizedBox(height: 4),
              SelectableText(value, style: context.txt.body),
            ]),
      );
}
