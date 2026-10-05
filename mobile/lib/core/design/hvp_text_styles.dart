import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hvp_colors.dart';

/// Font factory. Tests switch [useGoogleFonts] off so no network fetch is attempted.
///
/// Headline voice: Barlow Condensed, heavy + italic + uppercase (fight-card
/// graphics). It covers Vietnamese diacritics, so one family serves numerals,
/// English rank names and Vietnamese headings alike.
abstract final class HvpFonts {
  static bool useGoogleFonts = true;

  /// Giant numerals and hero words: extra-bold italic condensed.
  static TextStyle display(double size, Color color, {double letterSpacing = 0.4}) {
    if (useGoogleFonts) {
      return GoogleFonts.barlowCondensed(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: letterSpacing,
        height: 1.0,
      );
    }
    return TextStyle(
      fontFamily: 'Barlow Condensed',
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      letterSpacing: letterSpacing,
      height: 1.0,
    );
  }

  /// Headings / buttons / small caps labels. Pass [italic] for headings.
  static TextStyle label(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 1.0,
    bool italic = false,
  }) {
    final style = italic ? FontStyle.italic : FontStyle.normal;
    if (useGoogleFonts) {
      return GoogleFonts.barlowCondensed(
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontStyle: style,
        letterSpacing: letterSpacing,
        height: 1.15,
      );
    }
    return TextStyle(
      fontFamily: 'Barlow Condensed',
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      letterSpacing: letterSpacing,
      height: 1.15,
    );
  }

  static TextStyle body(double size, Color color, {FontWeight weight = FontWeight.w400}) {
    if (useGoogleFonts) {
      return GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: 1.4);
    }
    return TextStyle(fontFamily: 'Inter', fontSize: size, color: color, fontWeight: weight, height: 1.4);
  }

  static TextStyle mono(double size, Color color, {FontWeight weight = FontWeight.w500}) {
    if (useGoogleFonts) {
      return GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight, height: 1.3);
    }
    return TextStyle(fontFamily: 'JetBrains Mono', fontSize: size, color: color, fontWeight: weight, height: 1.3);
  }
}

/// Text style tokens bound to a colour palette.
@immutable
class HvpTextStyles extends ThemeExtension<HvpTextStyles> {
  HvpTextStyles(HvpColors c)
      : displayXL = HvpFonts.display(72, c.textPrimary),
        displayL = HvpFonts.display(48, c.textPrimary),
        displayM = HvpFonts.display(34, c.textPrimary),
        displayS = HvpFonts.display(26, c.textPrimary),
        titleL = HvpFonts.label(26, c.textPrimary, weight: FontWeight.w800, letterSpacing: 0.6, italic: true),
        titleM = HvpFonts.label(20, c.textPrimary, weight: FontWeight.w700, letterSpacing: 0.6, italic: true),
        titleS = HvpFonts.label(16, c.textPrimary, weight: FontWeight.w600, letterSpacing: 0.6),
        label = HvpFonts.label(13, c.textSecondary, letterSpacing: 1.6),
        labelStrong = HvpFonts.label(14, c.gold, weight: FontWeight.w700, letterSpacing: 1.6),
        bodyL = HvpFonts.body(16, c.textPrimary),
        body = HvpFonts.body(14, c.textPrimary),
        bodySmall = HvpFonts.body(12.5, c.textSecondary),
        caption = HvpFonts.body(11, c.textMuted),
        mono = HvpFonts.mono(13, c.textPrimary),
        monoLarge = HvpFonts.mono(20, c.textPrimary, weight: FontWeight.w700);

  /// Giant numerals / hero words (heavy italic condensed).
  final TextStyle displayXL;
  final TextStyle displayL;
  final TextStyle displayM;
  final TextStyle displayS;

  /// Condensed headings.
  final TextStyle titleL;
  final TextStyle titleM;
  final TextStyle titleS;
  final TextStyle label;
  final TextStyle labelStrong;

  final TextStyle bodyL;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle caption;

  final TextStyle mono;
  final TextStyle monoLarge;

  @override
  HvpTextStyles copyWith() => this;

  @override
  HvpTextStyles lerp(ThemeExtension<HvpTextStyles>? other, double t) {
    if (other is! HvpTextStyles) return this;
    return t < 0.5 ? this : other;
  }
}
