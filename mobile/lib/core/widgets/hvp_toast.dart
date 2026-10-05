import 'package:flutter/material.dart';

import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';

enum ToastType { info, success, error, warning }

/// Snack-bar based toast.
abstract final class HvpToast {
  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final c = context.hvp;
    final t = context.txt;
    final (IconData icon, Color color) = switch (type) {
      ToastType.success => (HvpIcons.checkCircle, c.emerald),
      ToastType.error => (HvpIcons.xCircle, c.red),
      ToastType.warning => (HvpIcons.warning, c.amber),
      ToastType.info => (HvpIcons.info, c.info),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: c.surfaceHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color, width: 1),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: t.body)),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) => show(context, message, type: ToastType.success);
  static void error(BuildContext context, String message) => show(context, message, type: ToastType.error);
}
