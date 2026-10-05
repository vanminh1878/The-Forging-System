import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';

/// Flame with a flickering animation and the streak length in weeks.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.weeks, this.size = 56, this.showLabel = true});

  final int weeks;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final active = weeks > 0;
    final color = active ? (weeks >= 8 ? c.red : c.amber) : c.textMuted;
    Widget flame = Icon(HvpIcons.fire, size: size, color: color);
    if (active) {
      flame = flame
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(begin: 0.93, end: 1.07, duration: 700.ms, curve: Curves.easeInOut);
    }
    return Semantics(
      label: active ? 'Chuỗi $weeks tuần liên tiếp' : 'Chưa có chuỗi tập',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: size * 1.2,
              height: size * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.fade(0.12),
                boxShadow: active
                    ? <BoxShadow>[BoxShadow(color: color.fade(0.35), blurRadius: size * 0.5)]
                    : null,
              ),
              child: Center(child: flame),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('$weeks', style: t.displayL.copyWith(color: color, fontSize: size * 0.8)),
                  Text('TUẦN LIÊN TIẾP', style: t.label),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
