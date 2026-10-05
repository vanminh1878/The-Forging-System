import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/dp_gauge.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/rank_badge.dart';
import '../../domain/rank_models.dart';
import '../../domain/rank_rules.dart';

/// Next rank target with the DP heat gauge.
class NextRankCard extends StatelessWidget {
  const NextRankCard({super.key, required this.progress});

  final RankProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final next = progress.next;
    if (next == null) return const SizedBox.shrink();
    final caption = progress.dpRemaining > 0
        ? 'Còn ${formatInt(progress.dpRemaining)} DP để lên ${next.displayName}'
        : 'Bạn đã đủ DP cho ${next.displayName}';
    return HvpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              RankBadge(rankOrder: next.order, size: 52, state: RankBadgeState.locked, glow: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('MỤC TIÊU TIẾP THEO', style: t.label),
                    Text(next.displayName, style: t.displayS),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DpGauge(current: estimateDp(progress), target: next.dpThreshold, caption: caption),
        ],
      ),
    );
  }
}
