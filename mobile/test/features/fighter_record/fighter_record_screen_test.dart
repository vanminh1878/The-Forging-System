import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/dp_gauge.dart';
import 'package:hvp_forging/core/widgets/empty_state.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/rank_badge.dart';
import 'package:hvp_forging/core/widgets/shimmer_box.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/fighter_record/domain/badge_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/rank_models.dart';
import 'package:hvp_forging/features/fighter_record/presentation/providers/fighter_record_providers.dart';
import 'package:hvp_forging/features/fighter_record/presentation/screens/fighter_record_screen.dart';
import 'package:hvp_forging/features/fighter_record/presentation/widgets/badge_tile.dart';
import 'package:hvp_forging/features/fighter_record/presentation/widgets/ledger_filter_bar.dart';
import 'package:hvp_forging/features/fighter_record/presentation/widgets/transaction_tile.dart';

import '../../helpers/test_harness.dart';
import 'fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeFighterRecordRepository repo) async {
  await pumpHvp(
    tester,
    const FighterRecordScreen(),
    overrides: <Override>[
      fighterRecordRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('user-1'),
    ],
  );
}

/// Rows below the fold are not built by the lazy list: scroll the (vertical) list to [target].
Future<void> _scrollTo(WidgetTester tester, Finder target) {
  return tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first,
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

PointsPage _page(int page, int totalPages, int from, int count) => PointsPage(
      items: <PointTransaction>[for (var i = 0; i < count; i++) sampleTx(from + i)],
      page: page,
      totalPages: totalPages,
      total: totalPages * count,
    );

void main() {
  group('Lên hạng tab', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final repo = FakeFighterRecordRepository()..onProgress = () => Completer<RankProgress>().future;
      await _pump(tester, repo);
      await tester.pump();
      expect(find.byType(ShimmerList), findsOneWidget);
    });

    testWidgets('shows the current rank, the gauge and the checklist', (tester) async {
      final repo = FakeFighterRecordRepository();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('THE DISCIPLINED'), findsOneWidget); // hero card
      expect(find.text('THE FORGED'), findsOneWidget); // next rank card
      expect(find.byType(DpGauge), findsOneWidget);
      expect(find.text('Đạt 3.000 DP'), findsOneWidget);
      expect(find.text('Còn thiếu 400 DP'), findsOneWidget);
      expect(find.text('Còn 400 DP để lên THE FORGED'), findsOneWidget);
      // Still in progress: no trial button.
      expect(find.widgetWithText(HvpButton, 'YÊU CẦU RANK TRIAL'), findsNothing);
    });

    testWidgets('error state offers a retry that reloads', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = () async => throw const ApiException(code: 'NETWORK_ERROR', message: 'Mất kết nối');
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Mất kết nối'), findsOneWidget);

      repo.onProgress = () async => sampleProgress();
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('THE DISCIPLINED'), findsOneWidget);
      expect(repo.progressCalls, 2);
    });

    testWidgets('max rank shows the celebratory empty state instead of a target', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = () async => sampleProgress(currentOrder: 7, withNext: false, status: RankStatus.maxRank, peakRankOrder: 7);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('THE LEGACY'), findsOneWidget);
      expect(find.text('HẠNG CAO NHẤT'), findsOneWidget);
      expect(find.byType(DpGauge), findsNothing);
    });

    testWidgets('requesting a Rank Trial asks for confirmation, then calls the API', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = () async => sampleProgress(status: RankStatus.trialRequired, dpOk: true, dpRemaining: 0);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(HvpButton, 'YÊU CẦU RANK TRIAL');
      await _scrollTo(tester, cta);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(repo.trialRequests, 0, reason: 'nothing is sent before the member confirms');
      await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
      await tester.pumpAndSettle();

      expect(repo.trialRequests, 1);
      expect(find.text('Đã gửi yêu cầu Rank Trial.'), findsOneWidget);
      expect(repo.progressCalls, 2, reason: 'progress is reloaded after the request');
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = () async => sampleProgress(status: RankStatus.trialRequired, dpOk: true, dpRemaining: 0);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(HvpButton, 'YÊU CẦU RANK TRIAL');
      await _scrollTo(tester, cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HvpButton, 'HUỶ'));
      await tester.pumpAndSettle();

      expect(repo.trialRequests, 0);
    });

    testWidgets('a rejected request shows the backend message', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = (() async => sampleProgress(status: RankStatus.trialRequired, dpOk: true, dpRemaining: 0))
        ..onRequestTrial = () async =>
            throw const ApiException(code: 'TRIAL_ALREADY_OPEN', message: 'Bạn đã có một yêu cầu đang chờ.', statusCode: 409);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(HvpButton, 'YÊU CẦU RANK TRIAL');
      await _scrollTo(tester, cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn đã có một yêu cầu đang chờ.'), findsOneWidget);
    });

    testWidgets('a pending trial replaces the button with a waiting notice', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onProgress = () async => sampleProgress(status: RankStatus.trialPending, dpOk: true, dpRemaining: 0, trialStatus: TrialStatus.pending);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('ĐANG CHỜ CHẤM'));
      expect(find.widgetWithText(HvpButton, 'YÊU CẦU RANK TRIAL'), findsNothing);
      expect(find.text('ĐANG CHỜ CHẤM'), findsOneWidget);
    });
  });

  group('Huy hiệu tab', () {
    testWidgets('renders 7 medallions with earned and locked states', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onBadges = (() async => <EarnedBadge>[
              EarnedBadge(rankId: 'r1', rankOrder: 1, earnedAt: DateTime.utc(2026, 1, 1)),
              EarnedBadge(rankId: 'r2', rankOrder: 2, earnedAt: DateTime.utc(2026, 2, 1)),
              EarnedBadge(rankId: 'r3', rankOrder: 3, earnedAt: DateTime.utc(2026, 4, 1)),
            ])
        ..onHistory = () async => <RankHistoryEntry>[
              RankHistoryEntry(
                id: 'h3',
                toRankId: 'r3',
                via: RankEarnVia.autoUpgrade,
                reason: 'Đạt 1.500 DP, đủ 3 tháng luyện tập.',
                dpAtChange: 1500,
                isRevoked: false,
                earnedAt: DateTime.utc(2026, 4, 1),
              ),
            ];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'HUY HIỆU');

      expect(find.byType(BadgeTile), findsNWidgets(7));
      final states = tester.widgetList<RankBadge>(find.byType(RankBadge)).map((b) => b.state).toList();
      expect(states.where((s) => s == RankBadgeState.earned).length, 3);
      expect(states.where((s) => s == RankBadgeState.locked).length, 4);
      expect(find.text('Tự động lên hạng: THE DISCIPLINED'), findsOneWidget);
    });

    testWidgets('a revoked badge is shown as removed', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onBadges = (() async => <EarnedBadge>[const EarnedBadge(rankId: 'r1', rankOrder: 1, earnedAt: null)])
        ..onHistory = () async => <RankHistoryEntry>[
              RankHistoryEntry(
                id: 'h9',
                toRankId: 'r2',
                via: RankEarnVia.autoDemote,
                reason: 'DP xuống dưới ngưỡng',
                dpAtChange: 400,
                isRevoked: true,
                earnedAt: DateTime.utc(2026, 5, 1),
              ),
            ];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'HUY HIỆU');

      final states = tester.widgetList<RankBadge>(find.byType(RankBadge)).map((b) => b.state).toList();
      expect(states.where((s) => s == RankBadgeState.revoked).length, 1);
      expect(find.text('Mất huy hiệu THE INITIATED'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onRanks = () async => throw const ApiException(code: 'X', message: 'Không tải được huy hiệu');
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'HUY HIỆU');

      expect(find.text('Không tải được huy hiệu'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);
    });
  });

  group('Sổ điểm tab', () {
    testWidgets('shows the monthly caps and the first page of transactions', (tester) async {
      final repo = FakeFighterRecordRepository()..onTransactions = (page, source) async => _page(1, 1, 1, 3);
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'SỔ ĐIỂM');

      expect(find.text('HẠN MỨC THÁNG NÀY'), findsOneWidget);
      expect(find.text('300 / 1.000'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(find.text('+50 DP'), findsWidgets);
      expect(find.text('+10 Marks'), findsWidgets);
      expect(find.text('XEM THÊM'), findsNothing, reason: 'single page');
    });

    testWidgets('empty ledger shows the empty state', (tester) async {
      final repo = FakeFighterRecordRepository();
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'SỔ ĐIỂM');

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('CHƯA CÓ GIAO DỊCH'), findsOneWidget);
    });

    testWidgets('"Xem thêm" loads the next page and appends it', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onTransactions = (page, source) async => page == 1 ? _page(1, 2, 1, 2) : _page(2, 2, 3, 2);
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'SỔ ĐIỂM');
      expect(find.byType(TransactionTile), findsNWidgets(2));

      final more = find.widgetWithText(HvpButton, 'XEM THÊM');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(repo.transactionPages, <int>[1, 2]);
      expect(find.byType(TransactionTile), findsNWidgets(4));
      expect(find.widgetWithText(HvpButton, 'XEM THÊM'), findsNothing);
    });

    testWidgets('choosing a filter reloads page 1 with that source', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onTransactions = (page, source) async => _page(1, 1, 1, 1);
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'SỔ ĐIỂM');

      // The chip row is a horizontal list: drag it (not the tab pager) until the chip is on screen.
      await tester.drag(
        find.descendant(of: find.byType(LedgerFilterBar), matching: find.byType(ListView)),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BUỔI TẬP'));
      await tester.pumpAndSettle();

      expect(repo.transactionFilters.first, isNull);
      expect(repo.transactionFilters.last, PointSource.session);
      expect(repo.transactionPages.last, 1);
    });

    testWidgets('ledger error shows a retry', (tester) async {
      final repo = FakeFighterRecordRepository()
        ..onTransactions = (page, source) async => throw const ApiException(code: 'X', message: 'Sổ điểm đang bảo trì');
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await _openTab(tester, 'SỔ ĐIỂM');

      expect(find.text('Sổ điểm đang bảo trì'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);
    });
  });
}
