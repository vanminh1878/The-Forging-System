import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// The HVP Boxing logo (mouthguard line art with "HVP" and "BOXING"), tinted
/// with the theme: belt gold on dark, ink on light.
///
/// The source artwork is `assets/brand/hvp_logo.png` (black on transparent).
class HvpLogo extends StatelessWidget {
  const HvpLogo({super.key, this.height = 40});

  final double height;

  static const String asset = 'assets/brand/hvp_logo.png';

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Semantics(
      label: 'HVP Boxing',
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          asset,
          height: height,
          fit: BoxFit.contain,
          color: c.isDark ? c.gold : c.textPrimary,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => SizedBox(height: height),
        ),
      ),
    );
  }
}
