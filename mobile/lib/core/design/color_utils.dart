import 'package:flutter/painting.dart';

extension HvpColorOpacity on Color {
  /// Opacity in 0..1 without the deprecated `withOpacity`.
  Color fade(double opacity) {
    final clamped = opacity < 0 ? 0.0 : (opacity > 1 ? 1.0 : opacity);
    return withAlpha((clamped * 255).round());
  }
}
