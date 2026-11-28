import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/staff_models.dart';
import 'staff_manage_sheet.dart';

class StaffMemberCard extends StatelessWidget {
  const StaffMemberCard({super.key, required this.member});
  final StaffMember member;

  @override
  Widget build(BuildContext context) => HvpCard(
        padding: const EdgeInsets.all(12),
        cut: 8,
        onTap: () => showHvpSheet<void>(context,
            title: 'Hồ sơ nhân sự',
            builder: (_) => StaffManageSheet(member: member)),
        child: Row(children: <Widget>[
          HvpAvatar(name: member.fullName, size: 38),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(member.fullName,
                    style: context.txt.titleS.copyWith(color: context.hvp.gold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                IconLabel(
                    icon: member.roles.any((r) => r.contains('COACH'))
                        ? HvpIcons.glove
                        : member.roles.contains('ADMIN')
                            ? HvpIcons.adminShield
                            : HvpIcons.deskStaff,
                    label: member.roleLabel),
                const SizedBox(height: 3),
                IconLabel(
                    icon: HvpIcons.storefront,
                    label: member.branchName ?? 'Chưa gán chi nhánh',
                    style: context.txt.caption),
                const SizedBox(height: 8),
                StatusChip(
                    label: StaffStatus.labelOf(member.accountStatus),
                    icon: switch (member.accountStatus) {
                      'ACTIVE' => HvpIcons.checkCircle,
                      'LOCKED' => HvpIcons.lock,
                      'DISABLED' => HvpIcons.block,
                      _ => HvpIcons.info,
                    },
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
