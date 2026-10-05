import 'package:flutter/material.dart';

import 'color_utils.dart';
import 'hvp_colors.dart';
import 'hvp_context.dart';

/// Page background: ring-canvas green with a spotlight glow from above, a dark
/// vignette and a few fight-poster slashes. Purely decorative; place it behind
/// the page content.
class HvpBackdrop extends StatelessWidget {
  const HvpBackdrop({super.key, required this.child, this.glow = 1, this.slashes = true});

  final Widget child;

  /// 0..1 strength of the spotlight glow.
  final double glow;
  final bool slashes;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(painter: _BackdropPainter(c, glow, slashes)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.c, this.glow, this.slashes);

  final HvpColors c;
  final double glow;
  final bool slashes;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[c.bg, c.isDark ? c.bgDeep : Color.lerp(c.bg, c.bgDeep, 0.35)!],
        ).createShader(rect),
    );

    // Spotlight from the ceiling.
    final glowColor = c.isDark ? c.pine : c.goldBright;
    final glowAlpha = (c.isDark ? 0.55 : 0.35) * glow;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1.05),
          radius: 0.95,
          colors: <Color>[glowColor.fade(glowAlpha), glowColor.fade(0)],
        ).createShader(rect),
    );

    if (slashes) {
      final slash = Paint()..color = (c.isDark ? c.gold : c.goldDeep).fade(c.isDark ? 0.045 : 0.07);
      final w = size.width;
      final h = size.height;
      Path band(double x, double width, double skew) => Path()
        ..moveTo(x, 0)
        ..lineTo(x + width, 0)
        ..lineTo(x + width - skew, h)
        ..lineTo(x - skew, h)
        ..close();
      canvas.drawPath(band(w * 0.74, w * 0.07, h * 0.28), slash);
      canvas.drawPath(band(w * 0.86, w * 0.025, h * 0.28), slash);
      canvas.drawPath(band(w * 0.05, w * 0.03, h * 0.28), slash);
    }

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.15,
          colors: <Color>[const Color(0x00000000), c.bgDeep.fade(c.isDark ? 0.75 : 0.10)],
          stops: const <double>[0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.c != c || old.glow != glow || old.slashes != slashes;
}
