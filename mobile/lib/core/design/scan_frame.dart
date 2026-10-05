import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'color_utils.dart';
import 'hvp_context.dart';

/// Corner-bracket viewfinder drawn above the camera preview of the QR check-in.
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key, this.size = 260, this.color, this.animated = true, this.child});

  final double size;
  final Color? color;
  final bool animated;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.hvp.gold;
    final laser = Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: accent,
        boxShadow: <BoxShadow>[BoxShadow(color: accent.fade(0.8), blurRadius: 10)],
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _BracketPainter(accent))),
          if (child != null) Positioned.fill(child: Padding(padding: const EdgeInsets.all(18), child: child)),
          if (animated)
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: laser
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: size - 40, duration: 1800.ms, curve: Curves.easeInOut),
            ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square;
    final len = size.shortestSide * 0.2;
    const inset = 2.5;
    final w = size.width - inset;
    final h = size.height - inset;
    final path = Path()
      ..moveTo(inset, len)
      ..lineTo(inset, inset)
      ..lineTo(len, inset)
      ..moveTo(w - len, inset)
      ..lineTo(w, inset)
      ..lineTo(w, len)
      ..moveTo(w, h - len)
      ..lineTo(w, h)
      ..lineTo(w - len, h)
      ..moveTo(len, h)
      ..lineTo(inset, h)
      ..lineTo(inset, h - len);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}
