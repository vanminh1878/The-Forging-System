import 'package:flutter/material.dart';

import 'hvp_colors.dart';
import 'hvp_text_styles.dart';

/// Builds the two supported themes: dark (default) and light.
abstract final class HvpTheme {
  static ThemeData dark() => _build(HvpColors.dark, Brightness.dark);
  static ThemeData light() => _build(HvpColors.light, Brightness.light);

  static ThemeData _build(HvpColors c, Brightness brightness) {
    final t = HvpTextStyles(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.gold,
      onPrimary: c.onGold,
      secondary: c.pineGlow,
      onSecondary: c.bgDeep,
      error: c.red,
      onError: c.onRed,
      surface: c.surface,
      onSurface: c.textPrimary,
    );
    final textTheme = TextTheme(
      displayLarge: t.displayXL,
      displayMedium: t.displayL,
      displaySmall: t.displayM,
      headlineLarge: t.titleL,
      headlineMedium: t.titleL,
      headlineSmall: t.titleM,
      titleLarge: t.titleL,
      titleMedium: t.titleM,
      titleSmall: t.titleS,
      bodyLarge: t.bodyL,
      bodyMedium: t.body,
      bodySmall: t.bodySmall,
      labelLarge: t.titleS,
      labelMedium: t.label,
      labelSmall: t.caption,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c, t],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: t.titleL.copyWith(fontSize: 24),
        iconTheme: IconThemeData(color: c.gold),
        actionsIconTheme: IconThemeData(color: c.gold),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHighest,
        contentTextStyle: t.body,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.gold, textStyle: t.titleS),
      ),
      listTileTheme: ListTileThemeData(iconColor: c.gold, textColor: c.textPrimary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.surfaceHighest, border: Border.all(color: c.borderStrong)),
        textStyle: t.body,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.gold, selectionHandleColor: c.gold),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.gold),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
