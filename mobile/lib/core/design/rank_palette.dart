import 'package:flutter/material.dart';

import 'hvp_colors.dart';

/// Metal tier of a rank medallion (rank order 1..7).
class RankPalette {
  const RankPalette({
    required this.light,
    required this.mid,
    required this.dark,
    required this.glow,
    required this.metal,
  });

  final Color light;
  final Color mid;
  final Color dark;
  final Color glow;

  /// Vietnamese name of the metal tier, used in semantics.
  final String metal;

  static const List<RankPalette> _tiers = <RankPalette>[
    RankPalette(light: Color(0xFFA9AEB7), mid: Color(0xFF6A6F78), dark: Color(0xFF3A3D44), glow: Color(0xFF8A8F98), metal: 'sắt'),
    RankPalette(light: Color(0xFFE6A878), mid: Color(0xFFB0693A), dark: Color(0xFF6E3B1C), glow: Color(0xFFD08A55), metal: 'đồng'),
    RankPalette(light: Color(0xFFF4F7FB), mid: Color(0xFFB8C0CC), dark: Color(0xFF6F7886), glow: Color(0xFFD5DBE4), metal: 'bạc'),
    RankPalette(light: Color(0xFFFFE590), mid: Color(0xFFE0A92E), dark: Color(0xFF8A5E0C), glow: Color(0xFFF2C450), metal: 'vàng'),
    RankPalette(light: Color(0xFFFF9A88), mid: Color(0xFFD8392B), dark: Color(0xFF7A1812), glow: Color(0xFFE5513F), metal: 'đỏ máu'),
    RankPalette(light: Color(0xFFCDB8FF), mid: Color(0xFF7E5BD6), dark: Color(0xFF35206F), glow: Color(0xFF9B7BEF), metal: 'hắc diện'),
    RankPalette(light: Color(0xFFFFFFFF), mid: Color(0xFF7FD8E8), dark: Color(0xFF1F7A8C), glow: Color(0xFFB6F0FA), metal: 'kim cương'),
  ];

  static RankPalette of(int order) {
    final index = order < 1 ? 0 : (order > _tiers.length ? _tiers.length - 1 : order - 1);
    return _tiers[index];
  }

  /// Greyed palette for locked / revoked medallions.
  static RankPalette locked(HvpColors c) => RankPalette(
        light: c.surfaceHighest,
        mid: c.surfaceHigh,
        dark: c.border,
        glow: c.border,
        metal: 'khoá',
      );

  SweepGradient get ringGradient => SweepGradient(
        colors: <Color>[light, mid, dark, mid, light, mid, dark, mid, light],
      );

  RadialGradient get discGradient => RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: <Color>[light, mid, dark],
        stops: const <double>[0.0, 0.55, 1.0],
      );
}

/// Rank names; kept in design because several widgets render them in the medallion.
const List<String> kRankCodes = <String>[
  'THE_UNKNOWN',
  'THE_INITIATED',
  'THE_DISCIPLINED',
  'THE_FORGED',
  'THE_FIGHTER',
  'THE_UNBROKEN',
  'THE_LEGACY',
];

const List<String> kRomanNumerals = <String>['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

/// `THE_FORGED` -> `THE FORGED` when the API does not send `nameEn`.
String rankNameFromCode(String code) => code.replaceAll('_', ' ');

/// Rank order for a code (1..7); 1 when unknown.
int rankOrderFromCode(String code) {
  final i = kRankCodes.indexOf(code);
  return i < 0 ? 1 : i + 1;
}
