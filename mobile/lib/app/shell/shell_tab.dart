import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_user.dart';
import 'role_shell.dart';

/// One bottom-bar destination of a role shell.
class ShellTab {
  const ShellTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  /// Absolute path, e.g. `/student/home`. Must start with the role's base path.
  final String path;

  /// Vietnamese label shown in the bar and as the app bar title.
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Body-only page: the shell provides the app bar and the bottom bar.
  final WidgetBuilder builder;
}

/// Builds the `StatefulShellRoute` (one preserved navigator per tab) of a role.
///
/// [raisedIndex] draws that tab as the raised centre button (student Check-in).
/// [accountInAppBar] adds the account sheet (theme + logout) to the app bar;
/// the student role has its own Hồ sơ tab instead.
StatefulShellRoute roleShellRoute({
  required AppRole role,
  required List<ShellTab> tabs,
  int? raisedIndex,
  bool accountInAppBar = true,
}) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => RoleShell(
      role: role,
      tabs: tabs,
      navigationShell: navigationShell,
      raisedIndex: raisedIndex,
      accountInAppBar: accountInAppBar,
    ),
    branches: <StatefulShellBranch>[
      for (final tab in tabs)
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: tab.path,
              builder: (context, state) => tab.builder(context),
            ),
          ],
        ),
    ],
  );
}
