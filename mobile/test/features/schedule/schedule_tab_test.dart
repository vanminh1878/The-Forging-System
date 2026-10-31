import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/empty_state.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/shimmer_box.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_models.dart';
import 'package:hvp_forging/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:hvp_forging/features/schedule/presentation/screens/schedule_tab.dart';

import '../../helpers/test_harness.dart';
import 'fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeScheduleRepository repo) async {
  await pumpHvp(
    tester,
    const Scaffold(body: ScheduleTab()),
    overrides: <Override>[
      scheduleRepositoryProvider.overrideWithValue(repo),
      scheduleTodayProvider.overrideWithValue(fixtureToday),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
}

void main() {
  testWidgets('shows a shimmer while loading', (tester) async {
    final repo = FakeScheduleRepository()
      ..onSchedule = (_) => Completer<ScheduleResult>().future;
    await _pump(tester, repo);
    await tester.pump();
    expect(find.byType(ShimmerList), findsOneWidget);
    expect(find.text('02/03 – 08/03'), findsOneWidget);
  });

  testWidgets('empty week shows the empty state', (tester) async {
    await _pump(tester, FakeScheduleRepository());
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('KHÔNG CÓ BUỔI NÀO.'), findsOneWidget);
  });

  testWidgets('error state retries', (tester) async {
    var calls = 0;
    final repo = FakeScheduleRepository()
      ..onSchedule = (_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException(
              code: 'X', message: 'Lỗi mạng', statusCode: 500);
        }
        return ScheduleResult(items: <ScheduleItem>[sampleItem('s1')]);
      };
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);

    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.textContaining('Boxing tối'), findsOneWidget);
  });

  testWidgets(
      'renders cards with status chips and the day filter narrows the list',
      (tester) async {
    final repo = FakeScheduleRepository()
      ..onSchedule = (_) async => ScheduleResult(items: <ScheduleItem>[
            sampleItem('s1', isToday: true),
            sampleItem('s2',
                date: '2026-03-06',
                title: 'Thể lực',
                status: SessionStatus.confirmedPass,
                isExam: true),
            sampleItem('s3',
                date: '2026-03-06',
                title: null,
                status: SessionStatus.cancelled,
                coach: null),
          ]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('TẤT CẢ BUỔI TẬP TUẦN NÀY'), findsOneWidget);
    expect(find.text('Thứ Tư · 04/03/2026 · Hôm nay'), findsOneWidget);
    expect(
        find.text('Boxing tối · 18:00–19:30 · Nguyễn Văn A'), findsOneWidget);
    expect(
        find.text('📝 Thể lực · 18:00–19:30 · Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Lớp nhóm · 18:00–19:30'), findsOneWidget);
    expect(find.text('SẮP TỚI'), findsOneWidget);
    expect(find.text('ĐẠT'), findsOneWidget);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);

    // Tap Friday (the strip cell labelled T6, number 6).
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(find.text('THỨ SÁU — BUỔI TRONG NGÀY'), findsOneWidget);
    expect(find.textContaining('Boxing tối'), findsNothing);
    expect(find.textContaining('Thể lực'), findsOneWidget);

    await tester.tap(find.text('✕ Bỏ lọc, xem cả tuần'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Boxing tối'), findsOneWidget);
  });

  testWidgets('next / previous / this week change the query date',
      (tester) async {
    final repo = FakeScheduleRepository();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sau'));
    await tester.pumpAndSettle();
    expect(find.text('09/03 – 15/03'), findsOneWidget);
    expect(repo.queries.last.anchorDate, DateTime.utc(2026, 3, 11));

    await tester.tap(find.text('Tuần này'));
    await tester.pumpAndSettle();
    expect(find.text('02/03 – 08/03'), findsOneWidget);
    expect(repo.queries.last.anchorDate, fixtureToday);

    await tester.tap(find.byTooltip('Trước'));
    await tester.pumpAndSettle();
    expect(find.text('23/02 – 01/03'), findsOneWidget);
  });
}
