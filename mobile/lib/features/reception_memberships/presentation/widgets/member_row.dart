import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../../reception_checkin/presentation/widgets/member_card.dart';
import 'member_avatar.dart';

/// A search result: who, account status, and the running package with its expiry.
class MemberRow extends StatelessWidget {
  const MemberRow({super.key, required this.member, this.onTap});

  final MemberHit member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final contact = <String>[
      if (member.phone != null) member.phone!,
      member.memberCode
    ].where((p) => p.isNotEmpty).join(' · ');
    final end = member.packageEndDate;
    final frozen = member.status == 'FROZEN';
    // A frozen learner reads differently at a glance: cool edge, snowflake on the avatar and chip.
    return HvpCard(
      onTap: onTap,
      accent: frozen ? context.hvp.info : null,
      semanticLabel:
          'Học viên ${member.fullName}${frozen ? ', đã đóng băng' : ''}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MemberAvatar(
              url: member.avatarUrl,
              name: member.fullName,
              size: 46,
              frozen: frozen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.fullName,
                    style: t.titleS,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (contact.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  IconLabel(icon: HvpIcons.phone, label: contact),
                ],
                if (member.packageName != null) ...<Widget>[
                  const SizedBox(height: 4),
                  IconLabel(
                      icon: HvpIcons.ticket,
                      label:
                          '${member.packageName} · ${end == null ? 'không thời hạn' : 'hết hạn ${formatCalendarDate(end)}'}'),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    memberStatusChip(member.status),
                    if (member.packageName == null)
                      const StatusChip(
                          label: 'Chưa có gói',
                          tone: ChipTone.warning,
                          icon: HvpIcons.warning),
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
