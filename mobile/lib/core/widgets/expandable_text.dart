import 'package:flutter/material.dart';

import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../design/hvp_layout.dart';

/// Text cut to [maxLines] with an ellipsis; when it really is cut, a button
/// shows the whole text and folds it back.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text,
      {super.key, required this.style, this.maxLines = 3});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            maxLines: widget.maxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: box.maxWidth);
          final cut = painter.didExceedMaxLines;
          painter.dispose();
          final c = context.hvp;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.text,
                style: widget.style,
                maxLines: _expanded ? null : widget.maxLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              if (cut)
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(HvpLayout.minTap, HvpLayout.minTap),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: Icon(_expanded ? HvpIcons.caretUp : HvpIcons.caretDown,
                      size: 18, color: c.gold),
                  label: Text(_expanded ? 'Thu gọn' : 'Xem đầy đủ',
                      style: context.txt.titleS.copyWith(color: c.gold)),
                ),
            ],
          );
        },
      );
}
