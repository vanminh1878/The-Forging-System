import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../utils/formatters.dart';

/// Heat gauge for DP: a segmented bar that warms from gold to red as the
/// member gets closer to the next rank, with a glove riding the fill edge.
class DpGauge extends StatelessWidget {
  const DpGauge({
    super.key,
    required this.current,
    required this.target,
    this.caption,
    this.height = 18,
    this.showNumbers = true,
  });

  final int current;
  final int target;
  final String? caption;
  final double height;
  final bool showNumbers;

  /// 0..1 progress; a zero target counts as complete.
  static double fractionOf(int current, int target) {
    if (target <= 0) return 1;
    final f = current / target;
    if (f < 0) return 0;
    return f > 1 ? 1 : f;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final fraction = fractionOf(current, target);
    final percent = (fraction * 100).floor();
    return Semantics(
      label: 'DP ${formatInt(current)} trên ${formatInt(target)}, đạt $percent phần trăm',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showNumbers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(formatInt(current), style: t.displayM.copyWith(color: c.gold)),
                            Text(' / ${formatInt(target)} DP', style: t.mono.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$percent%', style: t.mono.copyWith(color: c.textPrimary)),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                final gloveSize = height + 12;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    final fillWidth = width * value;
                    final gloveLeft = (fillWidth - gloveSize / 2).clamp(0.0, width - gloveSize).toDouble();
                    return SizedBox(
                      height: gloveSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            right: 0,
                            top: (gloveSize - height) / 2,
                            height: height,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.surfaceHigh,
                                borderRadius: BorderRadius.circular(height / 2),
                                border: Border.all(color: c.borderStrong),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: <Widget>[
                                  Container(
                                    width: fillWidth,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: _heat(c.heatColors, value)),
                                    ),
                                  ),
                                  Positioned.fill(child: CustomPaint(painter: _TickPainter(c.bg.fade(0.55)))),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: gloveLeft,
                            top: 0,
                            child: Container(
                              width: gloveSize,
                              height: gloveSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surface,
                                border: Border.all(color: c.red, width: 2),
                              ),
                              child: Icon(HvpIcons.glove, size: gloveSize * 0.58, color: c.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(caption!, style: t.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  /// Picks the portion of the heat palette that is "reached" so far.
  static List<Color> _heat(List<Color> palette, double progress) {
    final count = (1 + (progress * (palette.length - 1)).ceil()).clamp(2, palette.length).toInt();
    return palette.sublist(0, count);
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) => old.color != color;
}
