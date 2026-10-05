import 'package:flutter/widgets.dart';

/// Spacing, sizes and layout constants shared by every screen.
abstract final class HvpSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class HvpLayout {
  /// 16dp gutter on phones.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);

  /// Content inside a tab page must keep this much space at the bottom so the
  /// floating bottom bar never covers the last item.
  static const double navClearance = 108;

  static const double minTap = 48;
  static const double maxContentWidth = 560;

  /// Standard list padding for tab pages.
  static const EdgeInsets tabPagePadding = EdgeInsets.fromLTRB(16, 8, 16, navClearance);
}
