import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// Small row: coloured icon + label text, the info line of every card.
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.iconSize = 16,
    this.style,
    this.maxLines,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final double iconSize;

  /// Defaults to the small body style.
  final TextStyle? style;

  /// Cuts the label with an ellipsis after this many lines.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon,
                size: iconSize, color: iconColor ?? context.hvp.gold),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: style ?? context.txt.bodySmall,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
