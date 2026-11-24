import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// The look of [HvpTextField] (floating label, filled surface, rounded outline)
/// for fields that are not text boxes, such as dropdowns.
InputDecoration hvpFieldDecoration(
  BuildContext context, {
  required String label,
  bool required = false,
  String? hint,
  String? helper,
}) {
  final c = context.hvp;
  final t = context.txt;
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: required ? '$label *' : label,
    labelStyle: t.body.copyWith(color: c.textMuted),
    floatingLabelStyle: t.bodySmall.copyWith(color: c.textSecondary),
    hintText: hint,
    hintStyle: t.body.copyWith(color: c.textMuted),
    helperText: helper,
    helperStyle: t.caption,
    errorStyle: t.bodySmall.copyWith(color: c.red),
    filled: true,
    fillColor: c.surfaceHigh,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(c.borderStrong),
    enabledBorder: border(c.borderStrong),
    disabledBorder: border(c.border),
    focusedBorder: border(c.gold, width: 1.8),
    errorBorder: border(c.red),
    focusedErrorBorder: border(c.red, width: 1.8),
  );
}
