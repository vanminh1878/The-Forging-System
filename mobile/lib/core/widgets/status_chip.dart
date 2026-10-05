import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_colors.dart';
import '../design/hvp_context.dart';

enum ChipTone { neutral, gold, success, warning, danger, info }

/// Small pill with a tone: statuses, tags, filters.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = ChipTone.neutral, this.icon});

  final String label;
  final ChipTone tone;
  final IconData? icon;

  static Color foreground(HvpColors c, ChipTone tone) {
    switch (tone) {
      case ChipTone.gold:
        return c.gold;
      case ChipTone.success:
        return c.emerald;
      case ChipTone.warning:
        return c.amber;
      case ChipTone.danger:
        return c.red;
      case ChipTone.info:
        return c.info;
      case ChipTone.neutral:
        return c.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final fg = foreground(c, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: ShapeDecoration(
        color: tone == ChipTone.neutral ? c.surfaceHigh : fg.fade(0.16),
        shape: ChamferBorder(
          cut: 6,
          topLeft: true,
          bottomRight: true,
          side: BorderSide(color: fg.fade(0.5)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: t.label.copyWith(color: fg, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
