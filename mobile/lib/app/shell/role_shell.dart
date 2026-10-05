import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_backdrop.dart';
import '../../core/design/hvp_context.dart';
import '../../core/design/hvp_icons.dart';
import '../../core/widgets/hvp_app_bar.dart';
import '../../core/widgets/hvp_bottom_sheet.dart';
import '../../core/widgets/hvp_nav_bar.dart';
import '../../features/auth/domain/auth_user.dart';
import 'account_panel.dart';
import 'shell_tab.dart';

/// Scaffold shared by the four roles: titled app bar, the tab body kept alive
/// by go_router, and the floating bottom bar.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.role,
    required this.tabs,
    required this.navigationShell,
    this.raisedIndex,
    this.accountInAppBar = true,
  });

  final AppRole role;
  final List<ShellTab> tabs;
  final StatefulNavigationShell navigationShell;
  final int? raisedIndex;
  final bool accountInAppBar;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final current = tabs[index];
    final c = context.hvp;
    return Scaffold(
      extendBody: true,
      appBar: HvpAppBar(
        title: current.label,
        actions: <Widget>[
          if (accountInAppBar)
            IconButton(
              tooltip: 'Tài khoản',
              icon: Icon(HvpIcons.user, color: c.gold),
              onPressed: () => showHvpSheet<void>(
                context,
                title: 'Tài khoản',
                builder: (_) => const SingleChildScrollView(child: AccountPanel(inSheet: true)),
              ),
            ),
        ],
      ),
      body: HvpBackdrop(glow: 0.6, child: navigationShell),
      bottomNavigationBar: HvpNavBar(
        items: <HvpNavItem>[
          for (final tab in tabs) HvpNavItem(label: tab.label, icon: tab.icon, activeIcon: tab.activeIcon),
        ],
        currentIndex: index,
        raisedIndex: raisedIndex,
        onSelected: (i) => navigationShell.goBranch(i, initialLocation: i == index),
      ),
    );
  }
}
