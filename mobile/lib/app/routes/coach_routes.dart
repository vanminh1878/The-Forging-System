import 'package:go_router/go_router.dart';

import '../../core/design/hvp_icons.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../../features/auth/domain/auth_user.dart';
import '../route_paths.dart';
import '../shell/shell_tab.dart';

/// Coach routes (tabs: Hôm nay, Lớp & bài học, Challenge, Rank Trial, Lịch sử).
/// Replace a tab's `builder` with the feature screen when it is implemented.
List<RouteBase> coachRoutes() => <RouteBase>[
      roleShellRoute(
        role: AppRole.coach,
        tabs: <ShellTab>[
          ShellTab(
            path: CoachPaths.today,
            label: 'Hôm nay',
            icon: HvpIcons.calendar,
            activeIcon: HvpIcons.calendarFill,
            builder: (_) => const ComingSoonPage(
              title: 'Hôm nay',
              owner: 'feature: coach_today',
              icon: HvpIcons.calendar,
              description: 'Các buổi dạy trong ngày và điểm danh học viên.',
            ),
          ),
          ShellTab(
            path: CoachPaths.classes,
            label: 'Lớp & bài học',
            icon: HvpIcons.book,
            activeIcon: HvpIcons.bookFill,
            builder: (_) => const ComingSoonPage(
              title: 'Lớp & bài học',
              owner: 'feature: coach_classes',
              icon: HvpIcons.book,
            ),
          ),
          ShellTab(
            path: CoachPaths.challenge,
            label: 'Challenge',
            icon: HvpIcons.flag,
            activeIcon: HvpIcons.flagFill,
            builder: (_) => const ComingSoonPage(
              title: 'Challenge',
              owner: 'feature: coach_challenge',
              icon: HvpIcons.flag,
              description: 'Duyệt bài nộp thử thách của học viên.',
            ),
          ),
          ShellTab(
            path: CoachPaths.rankTrial,
            label: 'Rank Trial',
            icon: HvpIcons.trophyBold,
            activeIcon: HvpIcons.trophy,
            builder: (_) => const ComingSoonPage(
              title: 'Rank Trial',
              owner: 'feature: coach_rank_trial',
              icon: HvpIcons.trophy,
              description: 'Hàng chờ chấm Rank Trial (POST /rank-trials/:id/decision).',
            ),
          ),
          ShellTab(
            path: CoachPaths.history,
            label: 'Lịch sử',
            icon: HvpIcons.history,
            activeIcon: HvpIcons.historyFill,
            builder: (_) => const ComingSoonPage(
              title: 'Lịch sử',
              owner: 'feature: coach_history',
              icon: HvpIcons.history,
            ),
          ),
        ],
      ),
    ];
