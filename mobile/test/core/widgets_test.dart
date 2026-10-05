import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/design/hvp_icons.dart';
import 'package:hvp_forging/core/design/rank_palette.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/async_body.dart';
import 'package:hvp_forging/core/widgets/dp_gauge.dart';
import 'package:hvp_forging/core/widgets/empty_state.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/hvp_avatar.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/rank_badge.dart';
import 'package:hvp_forging/core/widgets/shimmer_box.dart';
import 'package:hvp_forging/core/widgets/status_chip.dart';

import '../helpers/test_harness.dart';

void main() {
  group('HvpButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await pumpHvp(tester, Scaffold(body: Center(child: HvpButton.primary(label: 'Lưu', onPressed: () => taps++))));
      await tester.tap(find.text('LƯU'));
      expect(taps, 1);
    });

    testWidgets('does nothing while loading or disabled', (tester) async {
      var taps = 0;
      await pumpHvp(
        tester,
        Scaffold(
          body: Column(
            children: <Widget>[
              HvpButton.primary(label: 'Đang gửi', loading: true, onPressed: () => taps++),
              const HvpButton.secondary(label: 'Tắt', onPressed: null),
            ],
          ),
        ),
      );
      await tester.tap(find.text('ĐANG GỬI'), warnIfMissed: false);
      await tester.tap(find.text('TẮT'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('states', () {
    testWidgets('EmptyState shows its message and runs the CTA', (tester) async {
      var pressed = 0;
      await pumpHvp(
        tester,
        Scaffold(
          body: EmptyState(
            icon: HvpIcons.tray,
            title: 'Chưa có dữ liệu',
            message: 'Hãy quay lại sau.',
            actionLabel: 'Làm mới',
            onAction: () => pressed++,
          ),
        ),
      );
      expect(find.text('CHƯA CÓ DỮ LIỆU'), findsOneWidget);
      expect(find.text('Hãy quay lại sau.'), findsOneWidget);
      await tester.tap(find.text('LÀM MỚI'));
      expect(pressed, 1);
    });

    testWidgets('ErrorState.fromError shows the API message and retries', (tester) async {
      var retried = 0;
      await pumpHvp(
        tester,
        Scaffold(
          body: ErrorState.fromError(
            const ApiException(code: 'X', message: 'Máy chủ bận'),
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text('Máy chủ bận'), findsOneWidget);
      await tester.tap(find.text('THỬ LẠI'));
      expect(retried, 1);
    });

    testWidgets('AsyncBody switches between loading, data and error', (tester) async {
      Future<void> pumpValue(AsyncValue<String> value) => pumpHvp(
            tester,
            Scaffold(
              body: AsyncBody<String>(
                value: value,
                onRetry: () {},
                builder: (context, data) => Text('data:$data'),
              ),
            ),
          );

      await pumpValue(const AsyncLoading<String>());
      expect(find.byType(ShimmerList), findsOneWidget);

      await pumpValue(const AsyncData<String>('ok'));
      expect(find.text('data:ok'), findsOneWidget);

      await pumpValue(const AsyncError<String>(ApiException(code: 'E', message: 'Hỏng'), StackTrace.empty));
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Hỏng'), findsOneWidget);
    });
  });

  group('DpGauge', () {
    test('fractionOf clamps and treats a zero target as complete', () {
      expect(DpGauge.fractionOf(50, 100), 0.5);
      expect(DpGauge.fractionOf(150, 100), 1);
      expect(DpGauge.fractionOf(-5, 100), 0);
      expect(DpGauge.fractionOf(10, 0), 1);
    });

    testWidgets('renders the numbers and percentage', (tester) async {
      await pumpHvp(tester, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: DpGauge(current: 750, target: 1500))));
      await tester.pumpAndSettle();
      expect(find.text('750'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('RankBadge', () {
    testWidgets('exposes a Vietnamese semantics label per state', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHvp(
        tester,
        const Scaffold(
          body: Row(
            children: <Widget>[
              RankBadge(rankOrder: 4),
              RankBadge(rankOrder: 5, state: RankBadgeState.locked),
              RankBadge(rankOrder: 6, state: RankBadgeState.revoked),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Huy hiệu hạng IV, đã đạt'), findsOneWidget);
      expect(find.bySemanticsLabel('Huy hiệu hạng V, chưa mở khoá'), findsOneWidget);
      expect(find.bySemanticsLabel('Huy hiệu hạng VI, đã bị gỡ'), findsOneWidget);
      semantics.dispose();
    });

    test('rank palette covers the 7 ranks and clamps out-of-range orders', () {
      expect(kRankCodes.length, 7);
      expect(RankPalette.of(0), same(RankPalette.of(1)));
      expect(RankPalette.of(99), same(RankPalette.of(7)));
      expect(rankOrderFromCode('THE_FORGED'), 4);
      expect(rankOrderFromCode('UNKNOWN'), 1);
      expect(rankNameFromCode('THE_FORGED'), 'THE FORGED');
    });
  });

  testWidgets('StatusChip upper-cases its label', (tester) async {
    await pumpHvp(tester, const Scaffold(body: StatusChip(label: 'Đang chờ', tone: ChipTone.warning)));
    expect(find.text('ĐANG CHỜ'), findsOneWidget);
  });

  test('HvpAvatar builds initials from first and last word', () {
    expect(HvpAvatar.initialsOf('Học Viên Mẫu'), 'HM');
    expect(HvpAvatar.initialsOf('  an '), 'A');
    expect(HvpAvatar.initialsOf(''), '?');
  });
}
