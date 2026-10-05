import 'dart:async';

import 'package:flutter/services.dart';

/// Haptic feedback that never throws: platforms without a vibrator (web,
/// desktop, tests) simply do nothing.
abstract final class Haptics {
  static void selection() => _fire(HapticFeedback.selectionClick);
  static void light() => _fire(HapticFeedback.lightImpact);
  static void medium() => _fire(HapticFeedback.mediumImpact);
  static void heavy() => _fire(HapticFeedback.heavyImpact);

  static void _fire(Future<void> Function() haptic) {
    try {
      unawaited(haptic().catchError((Object _) {}));
    } catch (_) {
      // Haptics are decoration only.
    }
  }
}
