import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import 'count_up_text.dart';
import 'hvp_card.dart';

/// Big condensed numeral with a small caption: DP, Marks, streak weeks...
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accent,
    this.onTap,
    this.animate = true,
  });

  final String label;
  final int value;
  final String? unit;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final color = accent ?? c.gold;
    final numberStyle = t.displayM.copyWith(color: color, fontSize: 36);
    return HvpCard(
      onTap: onTap,
      cut: 10,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      semanticLabel: '$label: $value${unit == null ? '' : ' $unit'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: color.fade(0.9)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label.toUpperCase(), style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: animate
                      ? CountUpText(value: value, style: numberStyle)
                      : Text('$value', style: numberStyle),
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 6),
                Text(unit!, style: t.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
