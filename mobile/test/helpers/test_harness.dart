import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';

/// Makes the test surface phone-sized (390x844 logical) and restores it afterwards.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wraps [child] in the app theme and a [ProviderScope]. Google Fonts are
/// switched off so no test ever tries to download a font.
Future<void> pumpHvp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  ThemeMode themeMode = ThemeMode.dark,
}) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: HvpTheme.light(),
        darkTheme: HvpTheme.dark(),
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
}
