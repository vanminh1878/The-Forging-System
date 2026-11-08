import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../core/widgets/hvp_button.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/armory/presentation/armory_catalog_screen.dart';
import '../../features/armory/presentation/redemption_detail_screen.dart';
import '../../features/armory/presentation/redemption_history_screen.dart';
import '../../features/checkin/presentation/checkin_scan_screen.dart';
import '../../features/checkin/presentation/checkin_tab.dart';
import '../../features/challenges/presentation/current_challenges_screen.dart';
import '../../features/challenges/presentation/open_challenges_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/courses_screen.dart';
import '../../features/courses/presentation/lesson_detail_screen.dart';
import '../../features/fighter_record/presentation/screens/fighter_record_screen.dart';
import '../../features/membership/presentation/screens/membership_screen.dart';
import '../../features/membership/presentation/widgets/membership_banner.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/widgets/notification_bell.dart';
import '../../features/schedule/presentation/screens/schedule_tab.dart';
import '../../features/schedule/presentation/screens/session_detail_screen.dart';
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
        actions: const <Widget>[NotificationBell()],
        tabs: <ShellTab>[
          ShellTab(
            path: StudentPaths.home,
            label: 'Trang chủ',
            icon: HvpIcons.home,
            activeIcon: HvpIcons.homeFill,
            builder: (context) => Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: MembershipBanner(
                    onAction: () => context.push(StudentPaths.membership),
                  ),
                ),
                Expanded(
                  child: ComingSoonPage(
                    title: 'Trang chủ',
                    owner: 'feature: student_home',
                    icon: HvpIcons.home,
                    description: 'Tổng quan DP, chuỗi tập, buổi tập sắp tới.',
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        HvpButton.gold(
                          label: 'Mở Fighter Record',
                          icon: HvpIcons.trophyBold,
                          small: true,
                          onPressed: () =>
                              context.push(StudentPaths.fighterRecord),
                        ),
                        HvpButton.gold(
                          label: 'Lộ trình khóa học',
                          icon: HvpIcons.book,
                          small: true,
                          onPressed: () => context.push(StudentPaths.courses),
                        ),
                        HvpButton.gold(
                          label: 'Thử thách',
                          icon: HvpIcons.flag,
                          small: true,
                          onPressed: () => context.push(StudentPaths.challenges),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ShellTab(
            path: StudentPaths.schedule,
            label: 'Lịch tập',
            icon: HvpIcons.calendar,
            activeIcon: HvpIcons.calendarFill,
            builder: (_) => const ScheduleTab(),
          ),
          ShellTab(
            path: StudentPaths.checkin,
            label: 'Check-in',
            icon: HvpIcons.scan,
            activeIcon: HvpIcons.scanFill,
            builder: (_) => const CheckinTab(),
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
        path: StudentPaths.armoryRedemptions,
        builder: (context, state) => const RedemptionHistoryScreen(),
      ),
      GoRoute(
        path: StudentPaths.armoryRedemptionPattern,
        builder: (context, state) => RedemptionDetailScreen(
          redemptionId: state.pathParameters['redemptionId'] ?? '',
        ),
      ),
      GoRoute(
        path: StudentPaths.checkinScan,
        builder: (context, state) => CheckinScanScreen(
            sessionId: state.uri.queryParameters['sessionId']),
      ),
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
        builder: (context, state) => const OpenChallengesScreen(),
      ),
      GoRoute(
        path: StudentPaths.currentChallenges,
        builder: (context, state) => const CurrentChallengesScreen(),
      ),
      GoRoute(
        path: StudentPaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: StudentPaths.membership,
        builder: (context, state) => const MembershipScreen(),
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
        path: StudentPaths.sessionPattern,
        builder: (context, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: StudentPaths.courses,
        builder: (context, state) => const CoursesScreen(),
      ),
      GoRoute(
        path: StudentPaths.coursePattern,
        builder: (context, state) => CourseDetailScreen(
            courseId: state.pathParameters['courseId'] ?? ''),
      ),
      GoRoute(
        path: StudentPaths.courseLessonPattern,
        builder: (context, state) => LessonDetailScreen(
          courseId: state.pathParameters['courseId'] ?? '',
          lessonNo: int.tryParse(state.pathParameters['lessonNo'] ?? '') ?? 0,
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
