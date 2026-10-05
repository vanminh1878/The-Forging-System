import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'color_utils.dart';
import 'hvp_colors.dart';
import 'hvp_context.dart';

/// Three ceiling lamps lighting one oval pool of light, like the lit sign of the
/// gym. The beams are exactly tangent to the oval and end on its upper arc; the
/// pool itself is one flat, slightly darker tint (no glow, nothing glaring).
///
/// Drawn in a 340x126 design space and stretched to the available width, so the
/// oval always sits behind a frame placed at y = 30..126 of the same box.
class HvpSpotlight extends StatelessWidget {
  const HvpSpotlight({super.key});

  /// Design-space size; callers lay the frame out against it.
  static const double designWidth = 340;
  static const double designHeight = 126;
  static const double frameTop = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(painter: _SpotlightPainter(c), size: const Size(double.infinity, designHeight)),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.c);

  final HvpColors c;

  static const Offset _center = Offset(170, 80);
  static const double _rx = 126;
  static const double _ry = 38;
  static const List<double> _lampX = <double>[62, 170, 278];

  Offset _onEllipse(double phi) => Offset(_center.dx + _rx * math.cos(phi), _center.dy + _ry * math.sin(phi));

  /// Fan from the lamp to the near arc of the oval, bounded by the two tangents.
  Path _beam(double lampX) {
    const lampY = 6.0;
    final u0 = (lampX - _center.dx) / _rx;
    final v0 = (lampY - _center.dy) / _ry;
    final d = math.sqrt(u0 * u0 + v0 * v0);
    final phi0 = math.atan2(v0, u0);
    final a = math.acos(1 / d);
    const steps = 14;
    final path = Path()..moveTo(lampX, lampY);
    for (var i = 0; i <= steps; i++) {
      final p = _onEllipse(phi0 - a + (2 * a) * i / steps);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / HvpSpotlight.designWidth, size.height / HvpSpotlight.designHeight);
    const rect = Rect.fromLTWH(0, 0, HvpSpotlight.designWidth, HvpSpotlight.designHeight);

    final beamColor = c.isDark ? const Color(0xFFF7DE9E) : const Color(0xFFD6A024);
    final beamOpacity = c.isDark ? 0.20 : 0.32;

    // One layer for all beams so overlaps never get darker, faded toward the lamps.
    canvas.saveLayer(rect, Paint()..color = Colors.white.fade(beamOpacity));
    final beamPaint = Paint()..color = beamColor;
    for (final x in _lampX) {
      canvas.drawPath(_beam(x), beamPaint);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.black.fade(0.33), Colors.black],
        ).createShader(rect),
    );
    canvas.restore();

    final oval = Rect.fromCenter(center: _center, width: _rx * 2, height: _ry * 2);
    canvas.drawOval(oval, Paint()..color = c.isDark ? const Color(0x21F7DE9E) : const Color(0x38D69E26));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.gold.fade(0.25),
    );

    final lamp = Paint()..color = c.gold;
    for (final x in _lampX) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 8, 0)
          ..relativeLineTo(16, 0)
          ..relativeLineTo(-3, 7)
          ..relativeLineTo(-10, 0)
          ..close(),
        lamp,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.c != c;
}
