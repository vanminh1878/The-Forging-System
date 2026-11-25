import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/storage/storage_providers.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/streak/domain/streak.dart';
import 'package:hvp_forging/features/streak/presentation/streak_providers.dart';
import 'package:hvp_forging/features/streak/presentation/streak_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';

class _FakeStreakRepository implements StreakRepository {
  _FakeStreakRepository(this.onSummary);

  Future<StreakSummary> Function() onSummary;

  @override
  Future<StreakSummary> summary() => onSummary();
}

StreakSummary _summary(
        {List<StreakLog> logs = const <StreakLog>[],
        Map<int, int> milestones = const <int, int>{}}) =>
    StreakSummary(
      currentStreakWeeks: 2,
      longestStreakWeeks: 4,
      currentWeekStart: DateTime(2026, 11, 23),
      sessionsThisWeek: 1,
      targetSessions: 3,
      availableFreezes: 1,
      milestones: milestones,
      logs: logs,
    );

Future<void> _pump(WidgetTester tester, _FakeStreakRepository repo,
        SharedPreferences prefs) =>
    pumpHvp(
      tester,
      const StreakScreen(),
      overrides: [
        streakRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('member-1'),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

void main() {
  testWidgets('shows streak progress, freeze and weekly history',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = _FakeStreakRepository(() async => _summary(logs: [
          StreakLog(
            weekStart: DateTime(2026, 11, 16),
            sessionsCount: 3,
            targetSessions: 3,
            result: 'FROZEN',
            streakBefore: 2,
            streakAfter: 2,
          ),
        ]));
    await _pump(tester, repo, await SharedPreferences.getInstance());
    await tester.pumpAndSettle();

    expect(find.text('2 tuần'), findsOneWidget);
    expect(find.text('1/3 buổi đã xác nhận'), findsOneWidget);
    expect(find.textContaining('Còn 1 Freeze'), findsOneWidget);
    expect(find.textContaining('3/3 buổi xác nhận'), findsOneWidget);
  });

  testWidgets('shows error state when loading streak summary fails',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = _FakeStreakRepository(
      () async => throw const ApiException(
          code: 'NETWORK_ERROR', message: 'Mất kết nối'),
    );
    await _pump(tester, repo, await SharedPreferences.getInstance());
    await tester.pumpAndSettle();

    expect(find.text('Mất kết nối'), findsOneWidget);
  });

  testWidgets('shows a milestone popup only once on this device',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = _FakeStreakRepository(() async => _summary(
          milestones: const <int, int>{4: 20},
          logs: [
            StreakLog(
              weekStart: DateTime(2026, 11, 16),
              sessionsCount: 3,
              targetSessions: 3,
              result: 'INCREASED',
              streakBefore: 3,
              streakAfter: 4,
            ),
          ],
        ));
    final prefs = await SharedPreferences.getInstance();
    await _pump(tester, repo, prefs);
    await tester.pumpAndSettle();
    expect(find.text('MỐC 4 TUẦN!'), findsOneWidget);
    await tester.tap(find.text('TIẾP TỤC'));
    await tester.pumpAndSettle();

    expect(prefs.getBool('streak_milestone:member-1:2026-11-16:4'), isTrue);
  });
}
