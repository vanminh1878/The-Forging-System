import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/member_hit.dart';

/// A learner at the front desk: who they are and whether they can train (account status, package).
class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.member, this.onTap});

  final MemberHit member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final contact = <String>[
      if (member.phone != null) member.phone!,
      member.memberCode
    ].where((p) => p.isNotEmpty).join(' · ');
    return HvpCard(
      onTap: onTap,
      semanticLabel: 'Học viên ${member.fullName}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HvpAvatar(url: member.avatarUrl, name: member.fullName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.fullName, style: t.titleS),
                if (contact.isNotEmpty) Text(contact, style: t.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    memberStatusChip(member.status),
                    if (member.packageName != null)
                      StatusChip(label: member.packageName!)
                    else
                      const StatusChip(
                          label: 'Chưa có gói', tone: ChipTone.warning),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Account status as a chip: only ACTIVE members can check in.
StatusChip memberStatusChip(String status) {
  switch (status) {
    case 'FROZEN':
      return const StatusChip(
          label: 'Đã đóng băng', tone: ChipTone.info, icon: HvpIcons.frozen);
    case 'INACTIVE':
      return const StatusChip(label: 'Không hoạt động', tone: ChipTone.danger);
    default:
      return const StatusChip(label: 'Hoạt động', tone: ChipTone.success);
  }
}
