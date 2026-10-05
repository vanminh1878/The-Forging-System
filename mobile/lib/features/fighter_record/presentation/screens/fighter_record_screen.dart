import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
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
    final c = context.hvp;
    final t = context.txt;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: HvpAppBar(
          title: 'Fighter Record',
          bottom: TabBar(
            labelColor: c.gold,
            unselectedLabelColor: c.textMuted,
            indicatorColor: c.gold,
            dividerColor: c.border,
            labelStyle: t.titleS,
            unselectedLabelStyle: t.titleS,
            tabs: const <Widget>[
              Tab(text: 'LÊN HẠNG'),
              Tab(text: 'HUY HIỆU'),
              Tab(text: 'SỔ ĐIỂM'),
            ],
          ),
        ),
        body: const Stack(
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
