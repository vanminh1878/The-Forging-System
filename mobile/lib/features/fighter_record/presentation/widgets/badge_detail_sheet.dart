import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/rank_badge.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/rank_rules.dart';
import 'badge_tile.dart';

/// Opens the detail sheet of one badge slot.
Future<void> showBadgeDetail(BuildContext context, BadgeSlot slot) {
  return showHvpSheet<void>(
    context,
    builder: (sheetContext) => _BadgeDetail(slot: slot),
  );
}

class _BadgeDetail extends StatelessWidget {
  const _BadgeDetail({required this.slot});

  final BadgeSlot slot;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final rank = slot.rank;
    final (String label, ChipTone tone) = switch (slot.state) {
      BadgeSlotState.earned => ('Đã đạt', ChipTone.success),
      BadgeSlotState.locked => ('Chưa mở khóa', ChipTone.neutral),
      BadgeSlotState.revoked => ('Đã bị gỡ', ChipTone.danger),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RankBadge(rankOrder: rank.order, size: 120, state: BadgeTile.badgeStateOf(slot.state)),
          const SizedBox(height: 16),
          Text(rank.displayName, style: t.displayM),
          if (rank.nameVi != null && rank.nameVi!.isNotEmpty) Text(rank.nameVi!, style: t.bodySmall),
          const SizedBox(height: 10),
          StatusChip(label: label, tone: tone),
          const SizedBox(height: 16),
          Text(
            'Yêu cầu: ${formatInt(rank.dpThreshold)} DP'
            '${rank.minActiveMonths > 0 ? ' · ${rank.minActiveMonths} tháng luyện tập' : ''}'
            '${rank.requiresTrial ? ' · Rank Trial' : ''}',
            style: t.body,
            textAlign: TextAlign.center,
          ),
          if (slot.earnedAt != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('Đạt ngày ${formatDate(slot.earnedAt!)}', style: t.bodySmall),
          ],
          if (slot.reason != null && slot.reason!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(slot.reason!, style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
