import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_context.dart';

/// Chamfered (angled-corner) surface used for every card in the app, like a
/// fight-card panel: a gold-edged cut corner, optional coloured left edge.
class HvpCard extends StatelessWidget {
  const HvpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.highlighted = false,
    this.cut = 12,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional accent colour: draws a coloured left edge and tints the border.
  final Color? accent;

  /// Hero style: green ring-canvas gradient with a gold edge.
  final bool highlighted;
  final double cut;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final borderColor = accent?.fade(0.55) ?? (highlighted ? c.gold.fade(0.7) : c.border);
    final shape = ChamferBorder(cut: cut, side: BorderSide(color: borderColor, width: 1));
    final content = Padding(padding: padding, child: child);
    final Gradient gradient = highlighted
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.isDark
                ? <Color>[c.pine.fade(0.85), c.pineDeep, c.surface]
                : <Color>[c.goldSoft, c.surface],
            stops: c.isDark ? const <double>[0, 0.55, 1] : null,
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.surfaceHigh.fade(c.isDark ? 0.55 : 1), c.surface],
          );
    final decorated = Ink(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: gradient,
        shadows: c.isDark
            ? null
            : <BoxShadow>[BoxShadow(color: c.shadow.fade(0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            width: cut,
            height: cut,
            child: ExcludeSemantics(
              child: CustomPaint(painter: _CornerPainter(c.gold.fade(highlighted || accent != null ? 0.95 : 0.55))),
            ),
          ),
          if (accent != null) Positioned(left: 0, top: cut, bottom: cut, child: Container(width: 3, color: accent)),
          content,
        ],
      ),
    );
    final interactive = onTap == null
        ? decorated
        : InkWell(customBorder: shape, onTap: onTap, child: decorated);
    final card = Material(
      type: MaterialType.transparency,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: interactive,
    );
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, button: onTap != null, container: true, child: card);
  }
}

/// Gold stroke across the cut top-left corner.
class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
