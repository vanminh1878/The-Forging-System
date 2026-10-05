import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../error/error_mapper.dart';
import 'hvp_button.dart';

/// Error panel with a retry button. Use [ErrorState.fromError] with caught objects.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.title = 'Không tải được dữ liệu'});

  factory ErrorState.fromError(Object? error, {Key? key, required VoidCallback onRetry}) =>
      ErrorState(key: key, message: errorMessage(error), onRetry: onRetry);

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.redSoft,
                border: Border.all(color: c.red.fade(0.5), width: 1.5),
              ),
              child: Icon(HvpIcons.warning, size: 36, color: c.red),
            ),
            const SizedBox(height: 16),
            Text(title.toUpperCase(), style: t.titleM, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: t.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            HvpButton.secondary(label: 'Thử lại', icon: HvpIcons.retry, onPressed: onRetry, small: true),
          ],
        ),
      ),
    );
  }
}
