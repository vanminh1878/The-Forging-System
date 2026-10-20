import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/staff/presentation/screens/staff_directory_screen.dart';
import '../route_paths.dart';
import '../shell/shell_tab.dart';

/// Admin routes (tabs: Dashboard, Thành viên, Đào tạo, Thử thách, Thông báo, Cấu hình).
/// Replace a tab's `builder` with the feature screen when it is implemented.
List<RouteBase> adminRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.admin,
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
            builder: (_) => const ComingSoonPage(
              title: 'Đào tạo',
              owner: 'feature: admin_training',
              icon: HvpIcons.book,
            ),
          ),
          ShellTab(
            path: AdminPaths.challenges,
            label: 'Thử thách',
            icon: HvpIcons.flag,
            activeIcon: HvpIcons.flagFill,
            builder: (_) => const ComingSoonPage(
              title: 'Thử thách',
              owner: 'feature: admin_challenges',
              icon: HvpIcons.flag,
              description: 'Challenge, đơn quà và kho quà.',
            ),
          ),
          ShellTab(
            path: AdminPaths.notifications,
            label: 'Thông báo',
            icon: HvpIcons.megaphone,
            activeIcon: HvpIcons.megaphoneFill,
            builder: (_) => const ComingSoonPage(
              title: 'Thông báo',
              owner: 'feature: admin_notifications',
              icon: HvpIcons.megaphone,
            ),
          ),
          ShellTab(
            path: AdminPaths.settings,
            label: 'Cấu hình',
            icon: HvpIcons.gear,
            activeIcon: HvpIcons.gearFill,
            builder: (_) => const ComingSoonPage(
              title: 'Cấu hình',
              owner: 'feature: admin_settings',
              icon: HvpIcons.gear,
              description: 'Quy tắc, hạng, chi nhánh và nhật ký hệ thống.',
            ),
          ),
        ],
      ),
    ];
