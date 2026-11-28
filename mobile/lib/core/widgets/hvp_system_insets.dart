import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hvp_context.dart';

/// Keeps every screen, sheet and dialog above the phone's own navigation bar.
///
/// Android draws the app edge to edge, so without this the last button or list
/// row sits under the system buttons. Wrap the whole app once with it; screens
/// then see no bottom inset and need no padding of their own for it.
class HvpSystemInsets extends StatelessWidget {
  const HvpSystemInsets({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final brightness = c.isDark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: c.bg,
        systemNavigationBarIconBrightness: brightness,
      ),
      child: ColoredBox(
        color: c.bg,
        child: SafeArea(top: false, left: false, right: false, child: child),
      ),
    );
  }
}
