import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import 'status_chip.dart';

/// Inline message box (errors, notices, dev hints).
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.message, this.tone = ChipTone.danger, this.icon, this.title});

  final String message;
  final String? title;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final color = StatusChip.foreground(c, tone);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.fade(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.fade(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon ?? (tone == ChipTone.danger ? HvpIcons.warning : HvpIcons.info), size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null) Text(title!.toUpperCase(), style: t.titleS.copyWith(color: color)),
                  Text(message, style: t.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
