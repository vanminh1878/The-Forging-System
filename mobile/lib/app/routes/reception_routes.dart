import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../features/auth/domain/auth_user.dart';
import '../route_paths.dart';
import '../shell/shell_tab.dart';

/// Reception routes (tabs: Check-in, Gói tập, Kho quà, Giao quà).
/// Replace a tab's `builder` with the feature screen when it is implemented.
List<RouteBase> receptionRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.reception,
        tabs: <ShellTab>[
          ShellTab(
            path: ReceptionPaths.checkin,
            label: 'Check-in',
            icon: HvpIcons.scan,
            activeIcon: HvpIcons.scanFill,
            builder: (_) => const ComingSoonPage(
              title: 'Check-in',
              owner: 'feature: reception_checkin',
              icon: HvpIcons.scan,
              description: 'Quét mã học viên và xác nhận điểm danh.',
            ),
          ),
          ShellTab(
            path: ReceptionPaths.memberships,
            label: 'Gói tập',
            icon: HvpIcons.ticket,
            activeIcon: HvpIcons.ticketFill,
            builder: (_) => const ComingSoonPage(
              title: 'Gói tập',
              owner: 'feature: reception_memberships',
              icon: HvpIcons.ticket,
              description: 'Yêu cầu, học viên và thống kê theo gói.',
            ),
          ),
          ShellTab(
            path: ReceptionPaths.stock,
            label: 'Kho quà',
            icon: HvpIcons.package,
            activeIcon: HvpIcons.packageFill,
            builder: (_) => const ComingSoonPage(
              title: 'Kho quà',
              owner: 'feature: reception_stock',
              icon: HvpIcons.package,
            ),
          ),
          ShellTab(
            path: ReceptionPaths.handover,
            label: 'Giao quà',
            icon: HvpIcons.gift,
            activeIcon: HvpIcons.giftFill,
            builder: (_) => const ComingSoonPage(
              title: 'Giao quà',
              owner: 'feature: reception_handover',
              icon: HvpIcons.gift,
            ),
          ),
        ],
      ),
    ];
