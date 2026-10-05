import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Number that counts up from 0 (or the previous value) when it appears/changes.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    this.textAlign,
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${formatInt(v.round())}$suffix',
        style: style,
        textAlign: textAlign,
        semanticsLabel: '$prefix${formatInt(value)}$suffix',
      ),
    );
  }
}
