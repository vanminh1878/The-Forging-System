import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_layout.dart';
import '../utils/haptics.dart';

enum HvpButtonVariant { primary, gold, secondary, ghost, danger }

/// Chamfered call-to-action button. 48dp minimum tap target, haptic tick, loading state.
class HvpButton extends StatelessWidget {
  const HvpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HvpButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  });

  const HvpButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = HvpButtonVariant.primary;

  const HvpButton.gold({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = HvpButtonVariant.gold;

  const HvpButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = HvpButtonVariant.secondary;

  const HvpButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = HvpButtonVariant.ghost;

  const HvpButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = HvpButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final HvpButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool small;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final Color fg;
    final Gradient? gradient;
    final Color? fill;
    final BorderSide side;
    var glow = false;
    switch (variant) {
      case HvpButtonVariant.primary:
      case HvpButtonVariant.gold:
        fg = c.onGold;
        gradient = c.goldGradient;
        fill = null;
        side = BorderSide.none;
        glow = true;
      case HvpButtonVariant.danger:
        fg = c.red;
        gradient = null;
        fill = c.redSoft;
        side = BorderSide(color: c.red.fade(0.6), width: 1);
      case HvpButtonVariant.secondary:
        fg = c.textPrimary;
        gradient = null;
        fill = c.surfaceHigh;
        side = BorderSide(color: c.borderStrong, width: 1);
      case HvpButtonVariant.ghost:
        fg = c.gold;
        gradient = null;
        fill = Colors.transparent;
        side = BorderSide(color: c.gold.fade(0.5), width: 1);
    }
    final shape = ChamferBorder(cut: small ? 9 : 13, side: side);
    final height = small ? 40.0 : HvpLayout.minTap + 6;
    final textStyle = (small ? t.titleS : t.titleM).copyWith(color: fg, letterSpacing: 1.4);

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: small ? 18 : 20, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: _enabled || loading ? 1 : 0.45,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height, minWidth: HvpLayout.minTap),
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: ShapeDecoration(
                shape: shape,
                color: fill,
                gradient: gradient,
                shadows: glow && _enabled
                    ? <BoxShadow>[BoxShadow(color: c.gold.fade(c.isDark ? 0.28 : 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                    : null,
              ),
              child: InkWell(
                customBorder: shape,
                onTap: _enabled
                    ? () {
                        Haptics.light();
                        onPressed!();
                      }
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20, vertical: small ? 8 : 12),
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
