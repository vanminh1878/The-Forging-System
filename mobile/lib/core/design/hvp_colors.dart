import 'package:flutter/material.dart';

/// Design tokens. The ONLY place with colour literals for the app chrome;
/// feature widgets read them through `context.hvp`.
///
/// Two themes only: [dark] ("ringside after dark": deep indigo + ember orange,
/// palette B) and [light] (lavender paper + orange). The `gold*` tokens hold the
/// orange accent and the `pine*` tokens the indigo panels; names are kept so
/// feature widgets do not change.
@immutable
class HvpColors extends ThemeExtension<HvpColors> {
  const HvpColors({
    required this.isDark,
    required this.bg,
    required this.bgDeep,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.border,
    required this.borderStrong,
    required this.gold,
    required this.goldBright,
    required this.goldDeep,
    required this.goldSoft,
    required this.pine,
    required this.pineDeep,
    required this.pineGlow,
    required this.red,
    required this.redDeep,
    required this.redSoft,
    required this.emerald,
    required this.emeraldSoft,
    required this.amber,
    required this.amberSoft,
    required this.info,
    required this.infoSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onGold,
    required this.onRed,
    required this.shadow,
  });

  final bool isDark;
  final Color bg;

  /// Darkest tone of the page backdrop (vignette edge).
  final Color bgDeep;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color border;
  final Color borderStrong;
  final Color gold;
  final Color goldBright;
  final Color goldDeep;
  final Color goldSoft;

  /// Brand indigo (the "ring canvas"): hero panels, spotlight, selected states.
  final Color pine;
  final Color pineDeep;
  final Color pineGlow;

  /// "Red corner": ring ropes, danger, streak heat. Never a page background.
  final Color red;
  final Color redDeep;
  final Color redSoft;
  final Color emerald;
  final Color emeraldSoft;
  final Color amber;
  final Color amberSoft;
  final Color info;
  final Color infoSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color onGold;
  final Color onRed;
  final Color shadow;

  /// Default theme: deep indigo, ember-orange accents, red-corner highlights.
  static const HvpColors dark = HvpColors(
    isDark: true,
    bg: Color(0xFF1A1733),
    bgDeep: Color(0xFF100E26),
    surface: Color(0xFF24204A),
    surfaceHigh: Color(0xFF2D2958),
    surfaceHighest: Color(0xFF383366),
    border: Color(0xFF3A3566),
    borderStrong: Color(0xFF524C8A),
    gold: Color(0xFFFF7A2F),
    goldBright: Color(0xFFFFA066),
    goldDeep: Color(0xFFE05A12),
    goldSoft: Color(0x2EFF7A2F),
    pine: Color(0xFF4A44A8),
    pineDeep: Color(0xFF262266),
    pineGlow: Color(0xFF7C75E0),
    red: Color(0xFFEF4B5F),
    redDeep: Color(0xFFB3243A),
    redSoft: Color(0x29EF4B5F),
    emerald: Color(0xFF62C792),
    emeraldSoft: Color(0x2E62C792),
    amber: Color(0xFFFFC266),
    amberSoft: Color(0x29FFC266),
    info: Color(0xFF8DBBDA),
    infoSoft: Color(0x298DBBDA),
    textPrimary: Color(0xFFEFEDFB),
    textSecondary: Color(0xFFC9C5EA),
    textMuted: Color(0xFF9C97C9),
    onGold: Color(0xFF1C0A02),
    onRed: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
  );

  /// Lavender paper variant of palette B.
  static const HvpColors light = HvpColors(
    isDark: false,
    bg: Color(0xFFF4F2FB),
    bgDeep: Color(0xFFE6E2F5),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF0EEF9),
    surfaceHighest: Color(0xFFE4E0F3),
    border: Color(0xFFD3CFE8),
    borderStrong: Color(0xFFB3ADD6),
    gold: Color(0xFFC94A05),
    goldBright: Color(0xFFF0792A),
    goldDeep: Color(0xFF9F3600),
    goldSoft: Color(0x24C94A05),
    pine: Color(0xFF3B3590),
    pineDeep: Color(0xFF1E1A5C),
    pineGlow: Color(0xFF5B54C9),
    red: Color(0xFFC0243C),
    redDeep: Color(0xFF8E1B2C),
    redSoft: Color(0x1FC0243C),
    emerald: Color(0xFF256B45),
    emeraldSoft: Color(0x1F256B45),
    amber: Color(0xFFB06A0F),
    amberSoft: Color(0x29B06A0F),
    info: Color(0xFF2A5D82),
    infoSoft: Color(0x1F2A5D82),
    textPrimary: Color(0xFF1A1633),
    textSecondary: Color(0xFF4A4570),
    textMuted: Color(0xFF7A74A0),
    onGold: Color(0xFFFFFFFF),
    onRed: Color(0xFFFFFFFF),
    shadow: Color(0xFF2A2457),
  );

  /// Ember orange: the primary call-to-action fill.
  LinearGradient get goldGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[goldBright, gold, goldDeep],
      );

  LinearGradient get redGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[red, redDeep],
      );

  /// Indigo hero panels (rank card, wordmark plate).
  LinearGradient get pineGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[pine, pineDeep],
      );

  /// Heat colours for gauges: cold -> hot.
  List<Color> get heatColors => <Color>[goldDeep, gold, amber, red];

  @override
  HvpColors copyWith() => this;

  @override
  HvpColors lerp(ThemeExtension<HvpColors>? other, double t) {
    if (other is! HvpColors) return this;
    return t < 0.5 ? this : other;
  }
}
