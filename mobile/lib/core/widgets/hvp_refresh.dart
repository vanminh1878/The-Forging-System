import 'package:flutter/material.dart';

import '../design/hvp_context.dart';
import '../utils/haptics.dart';

/// Pull-to-refresh with a gold ring and a bell-like haptic tick when the pull
/// threshold is reached. Child must be scrollable (use
/// `AlwaysScrollableScrollPhysics` for short lists).
class HvpRefresh extends StatelessWidget {
  const HvpRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return RefreshIndicator(
      color: c.gold,
      backgroundColor: c.surfaceHighest,
      strokeWidth: 3,
      displacement: 48,
      onRefresh: () async {
        Haptics.medium();
        try {
          await onRefresh();
        } catch (_) {
          // Errors are shown by the screen's own error state, never by the indicator.
        }
      },
      child: child,
    );
  }
}
