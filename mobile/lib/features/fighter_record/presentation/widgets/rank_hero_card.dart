import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/rank_palette.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/rank_badge.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/rank_models.dart';

/// Current rank: big medallion, English name in condensed display type.
class RankHeroCard extends StatelessWidget {
  const RankHeroCard({super.key, required this.progress});

  final RankProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final current = progress.current;
    final peak = progress.peakRankOrder;
    final showPeak = peak > current.order;
    final peakIndex = (peak < 1 ? 1 : (peak > kRomanNumerals.length ? kRomanNumerals.length : peak)) - 1;
    return HvpCard(
      highlighted: true,
      padding: const EdgeInsets.all(20),
      semanticLabel: 'Hạng hiện tại ${current.displayName}',
      child: Row(
        children: <Widget>[
          RankBadge(rankOrder: current.order, size: 96),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('HẠNG HIỆN TẠI', style: t.label),
                const SizedBox(height: 2),
                Text(current.displayName, style: t.displayM.copyWith(color: c.gold), maxLines: 2),
                if (current.nameVi != null && current.nameVi!.isNotEmpty) Text(current.nameVi!, style: t.bodySmall),
                if (showPeak) ...<Widget>[
                  const SizedBox(height: 10),
                  StatusChip(
                    label: 'Từng đạt hạng ${kRomanNumerals[peakIndex]}',
                    tone: ChipTone.info,
                    icon: HvpIcons.history,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
