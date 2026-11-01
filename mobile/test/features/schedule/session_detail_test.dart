import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_models.dart';
import 'package:hvp_forging/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:hvp_forging/features/schedule/presentation/screens/schedule_tab.dart';
import 'package:hvp_forging/features/schedule/presentation/screens/session_detail_screen.dart';

import '../../helpers/test_harness.dart';
import 'fixtures.dart';

Future<void> _pumpDetail(
    WidgetTester tester, FakeScheduleRepository repo) async {
  await pumpHvp(
    tester,
    const SessionDetailScreen(sessionId: 's1'),
    overrides: <Override>[
      scheduleRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  await tester.pumpAndSettle();
}

/// '/' hosts the schedule tab; the detail route is pushed on top of it.
Future<void> _pumpRouter(
    WidgetTester tester, FakeScheduleRepository repo) async {
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: ScheduleTab())),
      GoRoute(
        path: StudentPaths.sessionPattern,
        builder: (_, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
    ],
  );
  await pumpHvp(
    tester,
    Router<Object>(
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    ),
    overrides: <Override>[
      scheduleRepositoryProvider.overrideWithValue(repo),
      scheduleTodayProvider.overrideWithValue(fixtureToday),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'shows hero, status, check-in, completion, lesson plan, notes and the footer',
      (tester) async {
    final repo = FakeScheduleRepository()
      ..onSession = (id) async => SessionDetail(
            item: ScheduleItem(
              sessionId: id,
              title: 'Boxing tối',
              sessionType: SessionType.group,
              isExam: true,
              startsAt: DateTime.utc(2026, 3, 4, 11),
              endsAt: DateTime.utc(2026, 3, 4, 12, 30),
              date: '2026-03-04',
              isToday: false,
              branchName: 'The Corner',
              coachName: 'Nguyễn Văn A',
              status: SessionStatus.confirmedPass,
              checkinAt: DateTime.utc(2026, 3, 4, 10, 55),
              completionPercent: 85,
            ),
            lessonPlanTitle: 'JAB (1)',
            notes: 'Mang băng tay',
          );
    await _pumpDetail(tester, repo);

    expect(find.text('Thứ Tư, 04/03/2026 · 18:00–19:30'), findsOneWidget);
    expect(find.text('📝 Boxing tối'), findsOneWidget);
    expect(find.text('Nguyễn Văn A · The Corner'), findsOneWidget);
    expect(find.text('LỚP NHÓM'), findsOneWidget);
    expect(find.text('KIỂM TRA'), findsOneWidget);
    expect(find.text('ĐẠT'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('Đã check-in lúc 17:55'), findsOneWidget);
    expect(find.text('Hoàn thành 85%'), findsOneWidget);
    expect(find.text('JAB (1)'), findsOneWidget);
    expect(find.text('Mang băng tay'), findsOneWidget);
    expect(find.textContaining('học viên không tự đánh dấu hoàn thành'),
        findsOneWidget);
  });

  testWidgets('no lesson plan, notes or check-in: placeholder only',
      (tester) async {
    await _pumpDetail(tester, FakeScheduleRepository());
    expect(find.text('Buổi này chưa có giáo án chi tiết.'), findsOneWidget);
    expect(find.text('Ghi chú'), findsNothing);
    expect(find.textContaining('Đã check-in'), findsNothing);
    expect(find.textContaining('Hoàn thành'), findsNothing);
    expect(find.text('Sắp diễn ra'), findsOneWidget);
  });

  testWidgets('a non-404 error shows a retry', (tester) async {
    final repo = FakeScheduleRepository()
      ..onSession = (_) async =>
          throw const ApiException(code: 'X', message: 'Lỗi', statusCode: 500);
    await _pumpDetail(tester, repo);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('tapping a card pushes the detail route', (tester) async {
    final repo = FakeScheduleRepository()
      ..onSchedule =
          (_) async => ScheduleResult(items: <ScheduleItem>[sampleItem('s7')]);
    await _pumpRouter(tester, repo);

    await tester.tap(find.textContaining('Boxing tối'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(repo.sessionIds, <String>['s7']);
  });

  testWidgets('404 shows the toast and pops back to the schedule',
      (tester) async {
    final repo = FakeScheduleRepository()
      ..onSchedule = (_) async {
        return ScheduleResult(items: <ScheduleItem>[sampleItem('s7')]);
      }
      ..onSession = (_) async {
        throw const ApiException(
            code: 'NOT_FOUND', message: 'x', statusCode: 404);
      };
    await _pumpRouter(tester, repo);

    await tester.tap(find.textContaining('Boxing tối'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsNothing);
    expect(find.byType(ScheduleTab), findsOneWidget);
    expect(find.text('Buổi tập không còn trên lịch của bạn'), findsOneWidget);
  });
}
