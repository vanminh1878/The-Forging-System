import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../design/rank_palette.dart';

/// Visual state of a medallion.
enum RankBadgeState { earned, locked, revoked }

/// Metallic medallion for one of the 7 ranks.
///
/// Each rank has its own metal tier (iron -> diamond). Locked medallions are
/// greyed with a padlock, revoked ones are greyed with a red slash.
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rankOrder,
    this.size = 72,
    this.state = RankBadgeState.earned,
    this.glow = true,
    this.semanticLabel,
  });

  final int rankOrder;
  final double size;
  final RankBadgeState state;
  final bool glow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final earned = state == RankBadgeState.earned;
    final palette = earned ? RankPalette.of(rankOrder) : RankPalette.locked(c);
    final order = rankOrder.clamp(1, 7).toInt();
    final stateLabel = switch (state) {
      RankBadgeState.earned => 'đã đạt',
      RankBadgeState.locked => 'chưa mở khoá',
      RankBadgeState.revoked => 'đã bị gỡ',
    };
    return Semantics(
      label: semanticLabel ?? 'Huy hiệu hạng ${kRomanNumerals[order - 1]}, $stateLabel',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: palette.ringGradient,
                  boxShadow: earned && glow
                      ? <BoxShadow>[BoxShadow(color: palette.glow.fade(0.45), blurRadius: size * 0.28, spreadRadius: 1)]
                      : null,
                ),
              ),
              Container(
                width: size * 0.82,
                height: size * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.dark,
                  border: Border.all(color: palette.dark.fade(0.9), width: size * 0.02),
                ),
              ),
              Container(
                width: size * 0.7,
                height: size * 0.7,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.discGradient),
                child: Icon(
                  HvpIcons.rank(order),
                  size: size * 0.36,
                  color: earned ? palette.dark : c.textMuted,
                ),
              ),
              Positioned(
                bottom: size * 0.02,
                child: _RomanPlate(
                  text: kRomanNumerals[order - 1],
                  size: size,
                  background: earned ? palette.dark : c.surfaceHighest,
                  foreground: earned ? palette.light : c.textMuted,
                ),
              ),
              if (state == RankBadgeState.locked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Overlay(icon: HvpIcons.lock, color: c.textSecondary, background: c.surfaceHigh, size: size),
                ),
              if (state == RankBadgeState.revoked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Overlay(icon: HvpIcons.xCircle, color: c.red, background: c.surfaceHigh, size: size),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RomanPlate extends StatelessWidget {
  const _RomanPlate({required this.text, required this.size, required this.background, required this.foreground});

  final String text;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.1, vertical: size * 0.01),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.05),
        border: Border.all(color: foreground.fade(0.6), width: 0.8),
      ),
      child: Text(text, style: t.mono.copyWith(fontSize: size * 0.14, color: foreground, fontWeight: FontWeight.w700)),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.icon, required this.color, required this.background, required this.size});

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: Border.all(color: color.fade(0.6))),
      child: Icon(icon, size: size * 0.2, color: color),
    );
  }
}
