import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import 'hvp_button.dart';

/// Illustrated empty list: icon medallion, short Vietnamese message, optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.goldSoft,
                border: Border.all(color: c.gold.fade(0.5), width: 1.5),
              ),
              child: Icon(icon, size: 40, color: c.gold),
            ),
            const SizedBox(height: 18),
            Text(title.toUpperCase(), style: t.titleM, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 18),
              HvpButton.gold(label: actionLabel!, onPressed: onAction, small: true),
            ],
          ],
        ),
      ),
    );
  }
}
