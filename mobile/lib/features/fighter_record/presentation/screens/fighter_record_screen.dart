import 'package:flutter/material.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_sub_nav.dart';
import '../widgets/badges_tab.dart';
import '../widgets/points_tab.dart';
import '../widgets/rank_progress_tab.dart';
import '../widgets/rank_up_celebration.dart';

/// Fighter Record (student): rank progress, badges and the point ledger.
///
/// This feature is the reference implementation: copy its layering
/// (domain -> data -> presentation) for new features.
class FighterRecordScreen extends StatelessWidget {
  const FighterRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: HvpAppBar(
          title: 'Fighter Record',
          titleIcon: HvpIcons.trophy,
          bottom: HvpSubNav(
            items: <HvpSubNavItem>[
              HvpSubNavItem(label: 'Lên hạng', icon: HvpIcons.rocket),
              HvpSubNavItem(label: 'Huy hiệu', icon: HvpIcons.medal),
              HvpSubNavItem(label: 'Sổ điểm', icon: HvpIcons.receipt),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            TabBarView(
              children: <Widget>[
                RankProgressTab(),
                BadgesTab(),
                PointsTab(),
              ],
            ),
            RankUpCelebration(),
          ],
        ),
      ),
    );
  }
}
