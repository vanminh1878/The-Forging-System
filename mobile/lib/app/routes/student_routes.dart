import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../core/widgets/hvp_button.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/armory/presentation/armory_catalog_screen.dart';
import '../../features/fighter_record/presentation/screens/fighter_record_screen.dart';
import '../route_paths.dart';
import '../shell/profile_tab.dart';
import '../shell/shell_tab.dart';

/// Student routes. To implement a placeholder, replace ONLY its builder line
/// with the feature's screen; to add a screen, add a `GoRoute` below and a
/// constant in `route_paths.dart`.
List<RouteBase> studentRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.student,
        raisedIndex: 2,
        accountInAppBar: false,
        tabs: <ShellTab>[
          ShellTab(
            path: StudentPaths.home,
            label: 'Trang chủ',
            icon: HvpIcons.home,
            activeIcon: HvpIcons.homeFill,
            builder: (context) => ComingSoonPage(
              title: 'Trang chủ',
              owner: 'feature: student_home',
              icon: HvpIcons.home,
              description: 'Tổng quan DP, chuỗi tập, buổi tập sắp tới.',
              action: HvpButton.gold(
                label: 'Mở Fighter Record',
                icon: HvpIcons.trophyBold,
                small: true,
                onPressed: () => context.push(StudentPaths.fighterRecord),
              ),
            ),
          ),
          ShellTab(
            path: StudentPaths.schedule,
            label: 'Lịch tập',
            icon: HvpIcons.calendar,
            activeIcon: HvpIcons.calendarFill,
            builder: (_) => const ComingSoonPage(
              title: 'Lịch tập',
              owner: 'feature: schedule',
              icon: HvpIcons.calendar,
            ),
          ),
          ShellTab(
            path: StudentPaths.checkin,
            label: 'Check-in',
            icon: HvpIcons.scan,
            activeIcon: HvpIcons.scanFill,
            builder: (_) => const ComingSoonPage(
              title: 'Check-in',
              owner: 'feature: checkin',
              icon: HvpIcons.scan,
              description: 'Quét mã QR tại quầy lễ tân để điểm danh.',
            ),
          ),
          ShellTab(
            path: StudentPaths.armory,
            label: 'Armory',
            icon: HvpIcons.armory,
            activeIcon: HvpIcons.armoryFill,
            builder: (_) => const ArmoryCatalogScreen(),
          ),
          ShellTab(
            path: StudentPaths.profile,
            label: 'Hồ sơ',
            icon: HvpIcons.user,
            activeIcon: HvpIcons.userFill,
            builder: (_) => const ProfileTab(),
          ),
        ],
      ),
      // ---- pushed screens (full screen, outside the shell) ----
      GoRoute(
        path: StudentPaths.fighterRecord,
        builder: (context, state) => const FighterRecordScreen(),
      ),
      GoRoute(
        path: StudentPaths.streak,
        builder: (context, state) => const ComingSoonPage(
          title: 'Chuỗi tập',
          owner: 'feature: streak',
          icon: HvpIcons.fire,
          standalone: true,
        ),
      ),
      GoRoute(
        path: StudentPaths.challenges,
        builder: (context, state) => const ComingSoonPage(
          title: 'Thử thách',
          owner: 'feature: challenges',
          icon: HvpIcons.flag,
          standalone: true,
        ),
      ),
      GoRoute(
        path: StudentPaths.notifications,
        builder: (context, state) => const ComingSoonPage(
          title: 'Thông báo',
          owner: 'feature: notifications',
          icon: HvpIcons.bell,
          standalone: true,
        ),
      ),
      GoRoute(
        path: StudentPaths.membership,
        builder: (context, state) => const ComingSoonPage(
          title: 'Gói tập',
          owner: 'feature: membership',
          icon: HvpIcons.ticket,
          standalone: true,
        ),
      ),
      GoRoute(
        path: StudentPaths.workLog,
        builder: (context, state) => const ComingSoonPage(
          title: 'Nhật ký tập luyện',
          owner: 'feature: work_log',
          icon: HvpIcons.list,
          standalone: true,
        ),
      ),
      GoRoute(
        path: StudentPaths.lessonPattern,
        builder: (context, state) => ComingSoonPage(
          title: 'Bài học',
          owner: 'feature: lessons (id ${state.pathParameters['id'] ?? '-'})',
          icon: HvpIcons.book,
          standalone: true,
        ),
      ),
    ];
