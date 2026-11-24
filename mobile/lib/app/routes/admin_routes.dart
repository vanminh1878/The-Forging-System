import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/branch_admin/presentation/screens/admin_settings_page.dart';
import '../../features/branch_admin/presentation/screens/branch_list_screen.dart';
import '../../features/armory_admin/presentation/screens/admin_armory_management_screen.dart';
import '../../features/armory_admin/presentation/screens/admin_armory_reward_form_screen.dart';
import '../../features/armory_admin/presentation/screens/admin_armory_tiers_screen.dart';
import '../../features/class_admin/presentation/screens/class_detail_screen.dart';
import '../../features/class_admin/presentation/screens/class_list_screen.dart';
import '../../features/package_admin/presentation/screens/package_list_screen.dart';
import '../../features/reception_memberships/presentation/screens/admin_renewal_requests_screen.dart';
import '../../features/admin_challenges/presentation/admin_challenge_form_screen.dart';
import '../../features/admin_challenges/presentation/admin_challenges_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/widgets/notification_bell.dart';
import '../../features/staff/presentation/screens/staff_directory_screen.dart';
import '../route_paths.dart';
import '../shell/shell_tab.dart';

/// Admin routes (tabs: Dashboard, Thành viên, Đào tạo, Thử thách, Thông báo, Cấu hình).
/// Replace a tab's `builder` with the feature screen when it is implemented.
List<RouteBase> adminRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.admin,
        actions: const <Widget>[
          NotificationBell(
              inboxPath: AdminPaths.notifications, inboxIsTab: true)
        ],
        tabs: <ShellTab>[
          ShellTab(
            path: AdminPaths.dashboard,
            label: 'Dashboard',
            icon: HvpIcons.chart,
            activeIcon: HvpIcons.chartFill,
            builder: (_) => const ComingSoonPage(
              title: 'Dashboard',
              owner: 'feature: admin_dashboard',
              icon: HvpIcons.chart,
            ),
          ),
          ShellTab(
            path: AdminPaths.members,
            label: 'Thành viên',
            icon: HvpIcons.users,
            activeIcon: HvpIcons.usersFill,
            builder: (_) => const StaffDirectoryScreen(),
          ),
          ShellTab(
            path: AdminPaths.training,
            label: 'Đào tạo',
            icon: HvpIcons.book,
            activeIcon: HvpIcons.bookFill,
            builder: (_) => const ClassListScreen(),
          ),
          ShellTab(
            path: AdminPaths.challenges,
            label: 'Thử thách',
            icon: HvpIcons.flag,
            activeIcon: HvpIcons.flagFill,
            builder: (_) => const AdminChallengesScreen(),
          ),
          ShellTab(
            path: AdminPaths.notifications,
            label: 'Thông báo',
            icon: HvpIcons.megaphone,
            activeIcon: HvpIcons.megaphoneFill,
            builder: (_) => const NotificationsScreen(
                enableTargets: false, enableIndividualRead: false),
          ),
          ShellTab(
            path: AdminPaths.settings,
            label: 'Cấu hình',
            icon: HvpIcons.gear,
            activeIcon: HvpIcons.gearFill,
            builder: (_) => const AdminSettingsPage(),
          ),
        ],
      ),
      // ---- pushed screens (full screen, outside the shell) ----
      GoRoute(
        path: AdminPaths.classDetailPattern,
        builder: (context, state) =>
            ClassDetailScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AdminPaths.branches,
        builder: (context, state) => const BranchListScreen(),
      ),
      GoRoute(
        path: AdminPaths.renewalRequests,
        builder: (context, state) => const AdminRenewalRequestsScreen(),
      ),
      GoRoute(
        path: AdminPaths.packages,
        builder: (context, state) => const PackageListScreen(),
      ),
      GoRoute(
        path: AdminPaths.armory,
        builder: (context, state) => const AdminArmoryManagementScreen(),
      ),
      GoRoute(
        path: AdminPaths.armoryRewards,
        builder: (context, state) => AdminArmoryManagementScreen(
          initialTab: 1,
          initialTierCode: state.uri.queryParameters['tierCode'],
        ),
      ),
      GoRoute(
        path: AdminPaths.armoryTierCreate,
        builder: (context, state) => const AdminArmoryTiersScreen(),
      ),
      GoRoute(
        path: AdminPaths.armoryRewardCreate,
        builder: (context, state) => const AdminArmoryRewardFormScreen(),
      ),
      GoRoute(
        path: AdminPaths.challengeCreate,
        builder: (context, state) => const AdminChallengeFormScreen(),
      ),
      GoRoute(
        path: AdminPaths.challengeEditPattern,
        builder: (context, state) => AdminChallengeFormScreen(
          challengeId: state.pathParameters['challengeId'],
        ),
      ),
    ];
