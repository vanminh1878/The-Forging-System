import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// Section title with a gold tape tick and an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 20, bottom: 10),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _SlashMark(height: subtitle == null ? 22 : 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(title.toUpperCase(), style: t.titleM.copyWith(letterSpacing: 1.0)),
                ),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: c.gold),
              child: Text(actionLabel!, style: t.titleS.copyWith(color: c.gold)),
            ),
        ],
      ),
    );
  }
}

/// Two skewed gold bars ("//"): the fight-card section marker.
class _SlashMark extends StatelessWidget {
  const _SlashMark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    Widget bar(double width, Gradient gradient) => Transform(
          transform: Matrix4.skewX(-0.45),
          child: Container(width: width, height: height, decoration: BoxDecoration(gradient: gradient)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        bar(5, c.goldGradient),
        const SizedBox(width: 3),
        bar(2.5, LinearGradient(colors: <Color>[c.gold, c.gold])),
      ],
    );
  }
}
