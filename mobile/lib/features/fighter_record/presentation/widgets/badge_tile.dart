import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rank_badge.dart';
import '../../domain/rank_rules.dart';

/// One medallion of the badge board with its name and a one-line caption.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.slot, required this.onTap});

  final BadgeSlot slot;
  final VoidCallback onTap;

  static RankBadgeState badgeStateOf(BadgeSlotState state) {
    switch (state) {
      case BadgeSlotState.earned:
        return RankBadgeState.earned;
      case BadgeSlotState.locked:
        return RankBadgeState.locked;
      case BadgeSlotState.revoked:
        return RankBadgeState.revoked;
    }
  }

  static String captionOf(BadgeSlot slot) {
    switch (slot.state) {
      case BadgeSlotState.earned:
        final at = slot.earnedAt;
        return at == null ? 'Đã đạt' : formatDate(at);
      case BadgeSlotState.locked:
        return '${formatInt(slot.rank.dpThreshold)} DP';
      case BadgeSlotState.revoked:
        return 'Đã bị gỡ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final earned = slot.state == BadgeSlotState.earned;
    return Semantics(
      button: true,
      label: '${slot.rank.displayName}, ${captionOf(slot)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RankBadge(
                rankOrder: slot.rank.order,
                size: 76,
                state: badgeStateOf(slot.state),
              ),
              const SizedBox(height: 8),
              Text(
                slot.rank.displayName,
                style: t.titleS.copyWith(color: earned ? c.textPrimary : c.textMuted),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(captionOf(slot), style: t.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
