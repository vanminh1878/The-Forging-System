import 'package:flutter/widgets.dart';

/// Puts focus on the first field whose check reports an error, so the keyboard
/// and the scroll position land on what the user has to fix. Returns true when
/// every check passed (nothing was focused).
bool focusFirstInvalid(List<(FocusNode, String? Function())> checks) {
  for (final (node, check) in checks) {
    if (check() != null) {
      node.requestFocus();
      return false;
    }
  }
  return true;
}
