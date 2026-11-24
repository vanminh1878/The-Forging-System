import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// Small row: coloured icon + label text.  Replaces the identical `_detail()`
/// private helpers that were copy-pasted across multiple Challenge screens.
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: iconSize, color: iconColor ?? context.hvp.gold),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: context.txt.bodySmall)),
        ],
      );
}
