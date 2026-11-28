import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../reception_checkin/presentation/widgets/member_card.dart';
import '../../domain/member_models.dart';
import 'member_avatar.dart';

/// Who the learner is, their account status and why it is not active.
class MemberHeaderCard extends StatelessWidget {
  const MemberHeaderCard({super.key, required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final lines = <(IconData, String)>[
      if (profile.phone != null) (HvpIcons.phone, profile.phone!),
      if (profile.email != null) (HvpIcons.mail, profile.email!),
      (HvpIcons.idCard, profile.memberCode),
      if (profile.homeBranchName != null)
        (HvpIcons.storefront, profile.homeBranchName!),
      if (profile.joinedAt != null)
        (HvpIcons.event, 'Tham gia ${formatDate(profile.joinedAt!)}'),
    ];
    return HvpCard(
      highlighted: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MemberAvatar(
              url: profile.avatarUrl,
              name: profile.fullName,
              size: 56,
              frozen: profile.status == 'FROZEN'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.fullName, style: t.titleM),
                for (final (icon, line) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: IconLabel(icon: icon, label: line),
                  ),
                const SizedBox(height: 8),
                memberStatusChip(profile.status),
                if (profile.statusReason != null) ...<Widget>[
                  const SizedBox(height: 6),
                  IconLabel(
                      icon: HvpIcons.note,
                      label: 'Lý do: ${profile.statusReason}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
