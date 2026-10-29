import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_context.dart';
import '../../core/design/hvp_icons.dart';
import '../../core/design/hvp_layout.dart';
import '../../core/widgets/hvp_card.dart';
import '../route_paths.dart';
import 'account_panel.dart';

/// Student "Hồ sơ" tab: account card, package entry, theme switch and logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: HvpLayout.tabPagePadding,
      children: <Widget>[
        const AccountPanel(),
        const SizedBox(height: 12),
        HvpCard(
          onTap: () => context.push(StudentPaths.membership),
          child: Row(
            children: <Widget>[
              Icon(HvpIcons.ticket, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Gói tập & gia hạn', style: context.txt.titleS)),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}
