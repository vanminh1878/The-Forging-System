import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/branch_qr/presentation/branch_qr_route.dart';
import '../../features/reception_checkin/domain/member_hit.dart';
import '../../features/reception_checkin/presentation/assisted_checkin_screen.dart';
import '../../features/reception_checkin/presentation/member_today_screen.dart';
import '../../features/reception_checkin/presentation/reception_checkin_tab.dart';
import '../../features/reception_gifts/presentation/gift_handover_tab.dart';
import '../../features/reception_memberships/presentation/screens/member_detail_screen.dart';
import '../../features/reception_memberships/presentation/screens/reception_memberships_tab.dart';
import '../../features/reception_stock/presentation/reception_stock_tab.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/widgets/notification_bell.dart';
import '../route_paths.dart';
import '../shell/shell_tab.dart';

/// Reception routes (tabs: Check-in, Gói tập, Kho quà, Giao quà).
/// Replace a tab's `builder` with the feature screen when it is implemented.
List<RouteBase> receptionRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.reception,
        actions: const <Widget>[
          NotificationBell(inboxPath: ReceptionPaths.notifications)
        ],
        tabs: <ShellTab>[
          ShellTab(
            path: ReceptionPaths.checkin,
            label: 'Check-in',
            icon: HvpIcons.scan,
            activeIcon: HvpIcons.scanFill,
            builder: (_) => const ReceptionCheckinTab(),
          ),
          ShellTab(
            path: ReceptionPaths.memberships,
            label: 'Gói tập',
            icon: HvpIcons.ticket,
            activeIcon: HvpIcons.ticketFill,
            builder: (_) => const ReceptionMembershipsTab(),
          ),
          ShellTab(
            path: ReceptionPaths.stock,
            label: 'Kho quà',
            icon: HvpIcons.package,
            activeIcon: HvpIcons.packageFill,
            builder: (_) => const ReceptionStockTab(),
          ),
          ShellTab(
            path: ReceptionPaths.handover,
            label: 'Giao quà',
            icon: HvpIcons.gift,
            activeIcon: HvpIcons.giftFill,
            builder: (_) => const GiftHandoverTab(),
          ),
        ],
      ),
      // ---- pushed screens (full screen, outside the shell) ----
      GoRoute(
        path: ReceptionPaths.branchQr,
        builder: (context, state) => const BranchQrRoute(),
      ),
      GoRoute(
        path: ReceptionPaths.memberTodayPattern,
        builder: (context, state) => MemberTodayScreen(
          memberId: state.pathParameters['memberId'] ?? '',
          member: state.extra is MemberHit ? state.extra! as MemberHit : null,
        ),
      ),
      GoRoute(
        path: ReceptionPaths.assistedCheckinPattern,
        builder: (context, state) => AssistedCheckinScreen(
          memberId: state.pathParameters['memberId'] ?? '',
          sessionId: state.pathParameters['sessionId'] ?? '',
          member: state.extra is MemberHit ? state.extra! as MemberHit : null,
        ),
      ),
      GoRoute(
        path: ReceptionPaths.membershipMemberPattern,
        builder: (context, state) => MemberDetailScreen(
          memberId: state.pathParameters['memberId'] ?? '',
        ),
      ),
      GoRoute(
        path: ReceptionPaths.notifications,
        builder: (context, state) => const NotificationsScreen(
            enableTargets: false, enableIndividualRead: false),
      ),
    ];
