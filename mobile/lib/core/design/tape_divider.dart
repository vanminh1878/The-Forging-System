import 'package:flutter/material.dart';

import 'color_utils.dart';
import 'hvp_context.dart';

/// Hand-wrap tape: a diagonal-striped band used as a divider/accent.
class TapeDivider extends StatelessWidget {
  const TapeDivider({super.key, this.height = 6, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TapePainter(
            stripe: (color ?? c.gold).fade(c.isDark ? 0.9 : 0.8),
            gap: c.border,
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  const _TapePainter({required this.stripe, required this.gap});

  final Color stripe;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = gap.fade(0.5));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..color = stripe;
    final step = size.height * 2.2;
    final skew = size.height;
    for (double x = -skew; x < size.width + skew; x += step) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + step / 2, size.height)
        ..lineTo(x + step / 2 + skew, 0)
        ..lineTo(x + skew, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TapePainter old) => old.stripe != stripe || old.gap != gap;
}

/// Three ring ropes (red, white, red), used as a section separator.
class RopeLine extends StatelessWidget {
  const RopeLine({super.key, this.spacing = 4});

  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ExcludeSemantics(
      child: SizedBox(
        height: spacing * 2 + 6,
        width: double.infinity,
        child: CustomPaint(painter: _RopePainter(c.red, c.isDark ? c.textPrimary : c.surface, spacing)),
      ),
    );
  }
}

class _RopePainter extends CustomPainter {
  const _RopePainter(this.rope, this.middle, this.spacing);

  final Color rope;
  final Color middle;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final y = 1.5 + i * (spacing + 1.0);
      final rect = Rect.fromLTWH(0, y, size.width, 2);
      final color = i == 1 ? middle : rope;
      final shader = LinearGradient(
        colors: <Color>[color.fade(0.0), color, color, color.fade(0.0)],
        stops: const <double>[0, 0.12, 0.88, 1],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) =>
      old.rope != rope || old.middle != middle || old.spacing != spacing;
}
