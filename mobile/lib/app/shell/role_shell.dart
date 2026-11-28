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
/// by go_router, and the floating bottom bar. The body ends above the bar.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.role,
    required this.tabs,
    required this.navigationShell,
    this.raisedIndex,
    this.accountInAppBar = true,
    this.profilePath,
    this.actions = const <Widget>[],
  });

  final AppRole role;
  final List<ShellTab> tabs;
  final StatefulNavigationShell navigationShell;
  final int? raisedIndex;
  final bool accountInAppBar;

  /// Profile screen opened from the round app bar button (roles without a
  /// profile tab).
  final String? profilePath;

  /// Extra app bar buttons of this role, shown before the account button (e.g. the student's bell).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final current = tabs[index];
    final profile = profilePath;
    return Scaffold(
      appBar: HvpAppBar(
        title: current.title ?? current.label,
        titleIcon: current.activeIcon,
        actions: <Widget>[
          ...actions,
          if (profile != null)
            _AccountButton(
              tooltip: 'Hồ sơ',
              onPressed: () => context.push(profile),
            )
          else if (accountInAppBar)
            _AccountButton(
              tooltip: 'Tài khoản',
              onPressed: () => showHvpSheet<void>(
                context,
                title: 'Tài khoản',
                builder: (_) => const SingleChildScrollView(
                    child: AccountPanel(inSheet: true)),
              ),
            ),
        ],
      ),
      body: HvpBackdrop(glow: 0.6, child: navigationShell),
      bottomNavigationBar: HvpNavBar(
        items: <HvpNavItem>[
          for (final tab in tabs)
            HvpNavItem(
                label: tab.label, icon: tab.icon, activeIcon: tab.activeIcon),
        ],
        currentIndex: index,
        raisedIndex: raisedIndex,
        onSelected: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
      ),
    );
  }
}

/// Round profile button in the top right corner of the staff shells.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: c.surfaceHigh,
          side: BorderSide(color: c.borderStrong),
        ),
        icon: Icon(HvpIcons.user, color: c.gold),
        onPressed: onPressed,
      ),
    );
  }
}
