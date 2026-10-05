import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Global switch for [HvpEntrance]. Widget tests turn it off because
/// flutter_animate schedules a `Future.delayed` per animated widget, which
/// would outlive the test.
bool hvpEntranceEnabled = true;

/// Staggered entrance (fade + slide up) for list items:
/// `card.entrance(index)`. The delay is capped so long lists do not feel slow.
extension HvpEntrance on Widget {
  Widget entrance(int index) {
    if (!hvpEntranceEnabled) return this;
    final step = index < 0 ? 0 : (index > 8 ? 8 : index);
    return animate(delay: Duration(milliseconds: 60 * step))
        .fadeIn(duration: const Duration(milliseconds: 280))
        .slideY(
          begin: 0.06,
          end: 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
  }
}
