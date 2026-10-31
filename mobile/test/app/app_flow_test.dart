import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/app/hvp_app.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/theme_mode_controller.dart';
import 'package:hvp_forging/core/storage/storage_providers.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/coming_soon_page.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/hvp_nav_bar.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/auth/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/test_harness.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  Map<String, Object> prefsValues = const <String, Object>{},
}) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const HvpApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HvpApp)));
}

Finder _navLabel(String label) => find.descendant(of: find.byType(HvpNavBar), matching: find.text(label));

void main() {
  testWidgets('without a session the app shows the login screen', (tester) async {
    await _pumpApp(tester, FakeAuthRepository());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HvpNavBar), findsNothing);
  });

  testWidgets('student lands on the 5-tab shell', (tester) async {
    await _pumpApp(tester, FakeAuthRepository(restored: makeUser(AppRole.student)));

    expect(find.byType(HvpNavBar), findsOneWidget);
    for (final label in <String>['Trang chủ', 'Lịch tập', 'Check-in', 'Armory', 'Hồ sơ']) {
      expect(_navLabel(label), findsOneWidget, reason: label);
    }
    expect(find.byType(ComingSoonPage), findsOneWidget);
  });

  testWidgets('placeholder tabs keep working when switching', (tester) async {
    await _pumpApp(tester, FakeAuthRepository(restored: makeUser(AppRole.student)));

    await tester.tap(_navLabel('Armory'));
    await tester.pumpAndSettle();

    expect(find.text('Phụ trách: feature: armory'), findsOneWidget);
  });

  const staffTabs = <AppRole, List<String>>{
    AppRole.coach: <String>['Hôm nay', 'Lớp & bài học', 'Challenge', 'Rank Trial', 'Lịch sử'],
    AppRole.reception: <String>['Check-in', 'Gói tập', 'Kho quà', 'Giao quà'],
    AppRole.admin: <String>['Dashboard', 'Thành viên', 'Đào tạo', 'Thử thách', 'Thông báo', 'Cấu hình'],
  };
  for (final entry in staffTabs.entries) {
    testWidgets('${entry.key.name} lands on its own shell', (tester) async {
      await _pumpApp(tester, FakeAuthRepository(restored: makeUser(entry.key)));
      for (final label in entry.value) {
        expect(_navLabel(label), findsOneWidget, reason: label);
      }
      // Staff roles reach theme + logout through the app bar account button.
      expect(find.byTooltip('Tài khoản'), findsOneWidget);
    });
  }

  testWidgets('profile tab: account card, theme switch persists, logout returns to login', (tester) async {
    final repo = FakeAuthRepository(restored: makeUser(AppRole.student));
    final container = await _pumpApp(tester, repo);

    await tester.tap(_navLabel('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Người Dùng student'), findsOneWidget);
    expect(find.text('HỌC VIÊN'), findsOneWidget);

    // Theme: dark by default, switch to light and check it was stored.
    expect(container.read(themeModeProvider), ThemeMode.dark);
    await tester.tap(find.text('SÁNG'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(container.read(sharedPreferencesProvider).getString(ThemeModeController.storageKey), 'light');
    expect(find.text('HỆ THỐNG'), findsNothing);

    // Logout goes through a confirmation sheet.
    await tester.ensureVisible(find.text('ĐĂNG XUẤT'));
    await tester.tap(find.text('ĐĂNG XUẤT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'ĐĂNG XUẤT').last);
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('stored theme preference is honoured on start', (tester) async {
    final container = await _pumpApp(
      tester,
      FakeAuthRepository(),
      prefsValues: <String, Object>{ThemeModeController.storageKey: 'light'},
    );
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('ThemeModeController.parse only knows light and dark', () {
    expect(ThemeModeController.parse('light'), ThemeMode.light);
    expect(ThemeModeController.parse('dark'), ThemeMode.dark);
    // A legacy "system" preference falls back to dark.
    expect(ThemeModeController.parse('system'), ThemeMode.dark);
    expect(ThemeModeController.parse('nonsense'), ThemeMode.dark);
    expect(ThemeModeController.parse(null), ThemeMode.dark);
  });
}
