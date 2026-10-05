import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/badge_models.dart';
import '../../domain/rank_rules.dart';

/// One row of the rank timeline with a coloured node on the left.
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.entry, required this.rankName, this.isLast = false});

  final RankHistoryEntry entry;
  final String rankName;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final Color node;
    if (entry.isRevoked) {
      node = c.red;
    } else if (entry.via == RankEarnVia.initial) {
      node = c.textMuted;
    } else if (entry.via == RankEarnVia.rankTrialPassed) {
      node = c.gold;
    } else {
      node = c.emerald;
    }
    final at = entry.earnedAt;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 6),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: node, shape: BoxShape.circle)),
                if (!isLast) Expanded(child: Container(width: 2, color: c.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(historyTitle(entry, rankName), style: t.body.copyWith(fontWeight: FontWeight.w600)),
                  if (entry.reason.isNotEmpty) Text(entry.reason, style: t.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    '${at == null ? '' : '${formatDate(at)} · '}${formatInt(entry.dpAtChange)} DP',
                    style: t.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
