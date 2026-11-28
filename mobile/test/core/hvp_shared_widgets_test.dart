import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/design/hvp_colors.dart';
import 'package:hvp_forging/core/design/hvp_icons.dart';
import 'package:hvp_forging/core/widgets/expandable_text.dart';
import 'package:hvp_forging/core/widgets/hvp_app_bar.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/hvp_filter_chip.dart';
import 'package:hvp_forging/core/widgets/hvp_nav_bar.dart';
import 'package:hvp_forging/core/widgets/hvp_refresh_overlay.dart';
import 'package:hvp_forging/core/widgets/hvp_sub_nav.dart';
import 'package:hvp_forging/core/widgets/hvp_system_insets.dart';
import 'package:hvp_forging/core/widgets/status_chip.dart';

import '../helpers/test_harness.dart';

/// A phone with a 48dp system navigation bar.
Widget _withSystemBar(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(bottom: 48),
          viewPadding: const EdgeInsets.only(bottom: 48),
        ),
        child: HvpSystemInsets(child: child),
      ),
    );

const _items = <HvpNavItem>[
  HvpNavItem(label: 'Một', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Hai', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Ba', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Bốn', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Năm', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Sáu', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
  HvpNavItem(label: 'Bảy', icon: HvpIcons.home, activeIcon: HvpIcons.homeFill),
];

Future<void> _pumpNav(WidgetTester tester, int count, {int current = 0}) =>
    pumpHvp(
      tester,
      Scaffold(
        bottomNavigationBar: HvpNavBar(
          items: _items.sublist(0, count),
          currentIndex: current,
          onSelected: (_) {},
        ),
      ),
    );

void main() {
  group('HvpSystemInsets', () {
    testWidgets('screens stop above the phone navigation bar', (tester) async {
      await pumpHvp(
        tester,
        _withSystemBar(
          const Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter, child: Text('cuối trang')),
          ),
        ),
      );
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getRect(find.text('cuối trang')).bottom,
          lessThanOrEqualTo(screen - 48));
    });

    testWidgets('screens below it see no bottom inset of their own',
        (tester) async {
      late EdgeInsets padding;
      await pumpHvp(
        tester,
        _withSystemBar(Builder(builder: (context) {
          padding = MediaQuery.paddingOf(context);
          return const SizedBox();
        })),
      );
      expect(padding.bottom, 0);
    });
  });

  group('HvpNavBar scroll hint', () {
    testWidgets('five destinations fit a 320dp phone without any arrow',
        (tester) async {
      await _pumpNav(tester, 5);
      tester.view.physicalSize = const Size(320 * 3, 700 * 3);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Xem thêm mục bên phải'), findsNothing);
      expect(find.byTooltip('Xem thêm mục bên trái'), findsNothing);
    });

    testWidgets('overflow shows an arrow that scrolls, then the opposite one',
        (tester) async {
      await _pumpNav(tester, 7);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Xem thêm mục bên phải'), findsOneWidget);
      expect(find.byTooltip('Xem thêm mục bên trái'), findsNothing);

      await tester.tap(find.byTooltip('Xem thêm mục bên phải'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Xem thêm mục bên trái'), findsOneWidget);
      expect(find.byTooltip('Xem thêm mục bên phải'), findsNothing);
    });

    testWidgets('the selected destination is scrolled into view',
        (tester) async {
      await _pumpNav(tester, 7, current: 6);
      await tester.pumpAndSettle();
      expect(find.text('Bảy').hitTestable(), findsOneWidget);
    });
  });

  testWidgets('HvpAppBar shows the page icon next to the title',
      (tester) async {
    await pumpHvp(
      tester,
      const Scaffold(
          appBar: HvpAppBar(title: 'Lịch tập', titleIcon: HvpIcons.calendar)),
    );
    expect(find.byIcon(HvpIcons.calendar), findsOneWidget);
    expect(find.text('LỊCH TẬP'), findsOneWidget);
  });

  testWidgets('HvpSubTabs: every section has an icon and is one tap away',
      (tester) async {
    await pumpHvp(
      tester,
      const Scaffold(
        body: HvpSubTabs(
          items: <HvpSubNavItem>[
            HvpSubNavItem(label: 'Buổi tập', icon: HvpIcons.calendar),
            HvpSubNavItem(label: 'Giáo án', icon: HvpIcons.book),
          ],
          children: <Widget>[Text('phần một'), Text('phần hai')],
        ),
      ),
    );
    expect(find.byIcon(HvpIcons.calendar), findsOneWidget);
    expect(find.byIcon(HvpIcons.book), findsOneWidget);
    expect(find.text('phần một'), findsOneWidget);
    expect(find.text('phần hai'), findsNothing);

    await tester.tap(find.text('GIÁO ÁN'));
    await tester.pumpAndSettle();
    expect(find.text('phần hai'), findsOneWidget);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('HvpFilterChip uses the accent colour in $mode',
        (tester) async {
      var taps = 0;
      await pumpHvp(
        tester,
        Scaffold(
          body: HvpFilterChip(
            label: 'Chờ xử lý',
            icon: HvpIcons.hourglass,
            selected: true,
            onSelected: () => taps++,
          ),
        ),
        themeMode: mode,
      );
      final colors = mode == ThemeMode.light ? HvpColors.light : HvpColors.dark;
      final theme = Theme.of(tester.element(find.byType(ChoiceChip)));
      expect(theme.chipTheme.selectedColor, colors.selected);
      expect(tester.widget<Icon>(find.byIcon(HvpIcons.hourglass)).color,
          colors.onSelected);
      expect(tester.getSize(find.byType(ChoiceChip)).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.text('Chờ xử lý'));
      expect(taps, 1);
    });
  }

  testWidgets('a solid chip is filled, so it stands out from the card',
      (tester) async {
    await pumpHvp(
      tester,
      const Scaffold(
          body: StatusChip(
              label: 'Vắng mặt', tone: ChipTone.danger, solid: true)),
    );
    final box = tester.widget<Container>(find.descendant(
        of: find.byType(StatusChip), matching: find.byType(Container)));
    expect((box.decoration! as ShapeDecoration).color, HvpColors.dark.red);
  });

  group('HvpRefreshOverlay', () {
    Future<void> pump(WidgetTester tester, ValueNotifier<bool> refreshing,
            VoidCallback onRow) =>
        pumpHvp(
          tester,
          Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: refreshing,
              builder: (_, value, __) => Column(children: <Widget>[
                HvpRefreshButton(
                    refreshing: value,
                    onPressed: () => refreshing.value = true),
                Expanded(
                  child: HvpRefreshOverlay(
                    refreshing: value,
                    child: Center(
                      child: TextButton(
                          onPressed: onRow, child: const Text('dòng cũ')),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );

    testWidgets(
        'covers the list, blocks taps and double refresh, then leaves after the minimum time',
        (tester) async {
      final refreshing = ValueNotifier<bool>(false);
      addTearDown(refreshing.dispose);
      var rowTaps = 0;
      await pump(tester, refreshing, () => rowTaps++);
      expect(find.text('Đang làm mới…'), findsNothing);

      await tester.tap(find.text('LÀM MỚI'));
      await tester.pump();
      expect(find.text('Đang làm mới…'), findsOneWidget);
      expect(
          tester
              .widget<HvpButton>(find.widgetWithText(HvpButton, 'LÀM MỚI'))
              .onPressed,
          isNull);
      await tester.tap(find.text('dòng cũ'), warnIfMissed: false);
      expect(rowTaps, 0);

      // The data came back at once: the curtain still holds.
      refreshing.value = false;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Đang làm mới…'), findsOneWidget);

      await tester.pump(HvpRefreshOverlay.minVisible);
      await tester.pumpAndSettle();
      expect(find.text('Đang làm mới…'), findsNothing);
      await tester.tap(find.text('dòng cũ'));
      expect(rowTaps, 1);
    });

    testWidgets('stays while a slow refresh is still running', (tester) async {
      final refreshing = ValueNotifier<bool>(false);
      addTearDown(refreshing.dispose);
      await pump(tester, refreshing, () {});
      refreshing.value = true;
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Đang làm mới…'), findsOneWidget);
      refreshing.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Đang làm mới…'), findsNothing);
    });
  });

  group('ExpandableText', () {
    Future<void> pump(WidgetTester tester, String text) => pumpHvp(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: ExpandableText(text,
                  style: const TextStyle(fontSize: 20), maxLines: 2),
            ),
          ),
        );

    // 200 = longest session title the server accepts.
    final cases = <String, String>{
      'no spaces': 'a' * 200,
      'Vietnamese': 'Lớp Quyền Anh nâng cao buổi tối ' * 6,
      'emoji': '🥊' * 100,
    };
    for (final entry in cases.entries) {
      testWidgets('a long title (${entry.key}) is cut and can be opened',
          (tester) async {
        await pump(tester, entry.value);
        expect(find.text('Xem đầy đủ'), findsOneWidget);
        expect(tester.widget<Text>(find.text(entry.value)).maxLines, 2);

        await tester.tap(find.text('Xem đầy đủ'));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.text(entry.value)).maxLines, isNull);
        expect(find.text('Thu gọn'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a short title has no button', (tester) async {
      await pump(tester, 'JAB (1)');
      expect(find.text('Xem đầy đủ'), findsNothing);
    });
  });
}
