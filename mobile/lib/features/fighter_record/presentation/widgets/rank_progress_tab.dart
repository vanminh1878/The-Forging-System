import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../domain/rank_models.dart';
import '../../domain/rank_rules.dart';
import '../providers/fighter_record_providers.dart';
import 'next_rank_card.dart';
import 'rank_hero_card.dart';
import 'requirements_card.dart';
import 'trial_panel.dart';

/// Tab "Lên hạng": current rank, next target, checklist and trial CTA.
class RankProgressTab extends ConsumerWidget {
  const RankProgressTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(rankProgressProvider);
    return AsyncBody<RankProgress>(
      value: progress,
      onRetry: () => ref.invalidate(rankProgressProvider),
      loading: const ShimmerList(itemCount: 3, itemHeight: 140),
      builder: (context, data) => HvpRefresh(
        onRefresh: () async {
          ref.invalidate(rankProgressProvider);
          await ref.read(rankProgressProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: _children(data),
        ),
      ),
    );
  }

  List<Widget> _children(RankProgress data) {
    final requirements = buildRequirements(data);
    final widgets = <Widget>[
      RankHeroCard(progress: data),
      if (data.isMaxRank)
        const EmptyState(
          icon: HvpIcons.crown,
          title: 'Hạng cao nhất',
          message: 'Bạn đã chinh phục hạng cao nhất của HVP. Hãy giữ vững phong độ!',
        )
      else ...<Widget>[
        NextRankCard(progress: data),
        const SectionHeader(title: 'Điều kiện lên hạng'),
        RequirementsCard(requirements: requirements),
        TrialPanel(progress: data),
      ],
    ];
    // Same spacing between blocks, staggered entrance.
    return <Widget>[
      for (var i = 0; i < widgets.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: widgets[i].entrance(i),
        ),
    ];
  }
}
