import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_context.dart';
import '../../core/design/hvp_icons.dart';
import '../../core/design/hvp_layout.dart';
import '../../core/widgets/hvp_card.dart';
import '../../features/profile/presentation/widgets/profile_details.dart';
import '../route_paths.dart';
import 'account_panel.dart';

/// "Hồ sơ" tab: account card, theme switch and logout. Students also get their
/// personal info and the package entry; staff have no learner profile
/// (`/me/profile` is for members only), so [studentSections] is off for them.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.studentSections = true});

  final bool studentSections;

  @override
  Widget build(BuildContext context) {
    if (!studentSections) {
      return ListView(
        padding: HvpLayout.tabPagePadding,
        children: const <Widget>[AccountPanel()],
      );
    }
    return ListView(
      padding: HvpLayout.tabPagePadding,
      children: <Widget>[
        AccountPanel(
          middle: <Widget>[
            const ProfileDetails(),
            const SizedBox(height: 12),
            HvpCard(
              onTap: () => context.push(StudentPaths.membership),
              child: Row(
                children: <Widget>[
                  Icon(HvpIcons.ticket, color: context.hvp.gold),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          Text('Gói tập & gia hạn', style: context.txt.titleS)),
                  Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
