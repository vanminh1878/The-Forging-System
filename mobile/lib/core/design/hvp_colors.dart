import 'package:flutter/material.dart';

/// Design tokens. The ONLY place with colour literals for the app chrome;
/// feature widgets read them through `context.hvp`.
///
/// Two themes only: [dark] ("ringside after dark": deep forest green + belt gold,
/// taken from the approved prototype) and [light] (warm paper + gold).
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

  /// Brand green (the "ring canvas"): hero panels, spotlight, selected states.
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

  /// Default theme: deep green felt, belt-gold accents, red-corner highlights.
  static const HvpColors dark = HvpColors(
    isDark: true,
    bg: Color(0xFF0C1A16),
    bgDeep: Color(0xFF07100D),
    surface: Color(0xFF13261F),
    surfaceHigh: Color(0xFF1A332B),
    surfaceHighest: Color(0xFF234239),
    border: Color(0xFF2A4B40),
    borderStrong: Color(0xFF3D6556),
    gold: Color(0xFFE8C278),
    goldBright: Color(0xFFF7DE9E),
    goldDeep: Color(0xFFC79A3B),
    goldSoft: Color(0x2EE8C278),
    pine: Color(0xFF1F7D5C),
    pineDeep: Color(0xFF0E3A2C),
    pineGlow: Color(0xFF3FBF8A),
    red: Color(0xFFEA5A43),
    redDeep: Color(0xFFA32A1E),
    redSoft: Color(0x29EA5A43),
    emerald: Color(0xFF62C792),
    emeraldSoft: Color(0x2E62C792),
    amber: Color(0xFFE8C278),
    amberSoft: Color(0x29E8C278),
    info: Color(0xFF8DBBDA),
    infoSoft: Color(0x298DBBDA),
    textPrimary: Color(0xFFEEF5F0),
    textSecondary: Color(0xFFC3D3CA),
    textMuted: Color(0xFF93AA9F),
    onGold: Color(0xFF1C1204),
    onRed: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
  );

  /// Warm paper variant of the approved prototype.
  static const HvpColors light = HvpColors(
    isDark: false,
    bg: Color(0xFFF5EEDC),
    bgDeep: Color(0xFFEBDFBE),
    surface: Color(0xFFFFFDF7),
    surfaceHigh: Color(0xFFFBF3DE),
    surfaceHighest: Color(0xFFF3E7C9),
    border: Color(0xFFDDD0AE),
    borderStrong: Color(0xFFC2B283),
    gold: Color(0xFFB7841E),
    goldBright: Color(0xFFE0A92E),
    goldDeep: Color(0xFF8F6512),
    goldSoft: Color(0x24B7841E),
    pine: Color(0xFF1F7D5C),
    pineDeep: Color(0xFF0E3A2C),
    pineGlow: Color(0xFF2FA374),
    red: Color(0xFFC0302A),
    redDeep: Color(0xFF9A2A22),
    redSoft: Color(0x1FC0302A),
    emerald: Color(0xFF256B45),
    emeraldSoft: Color(0x1F256B45),
    amber: Color(0xFFB06A0F),
    amberSoft: Color(0x29B06A0F),
    info: Color(0xFF2A5D82),
    infoSoft: Color(0x1F2A5D82),
    textPrimary: Color(0xFF231705),
    textSecondary: Color(0xFF5B4A2E),
    textMuted: Color(0xFF8C7A57),
    onGold: Color(0xFF1C1204),
    onRed: Color(0xFFFFFFFF),
    shadow: Color(0xFF4A3407),
  );

  /// Belt gold: the primary call-to-action fill.
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

  /// Green hero panels (rank card, wordmark plate).
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
