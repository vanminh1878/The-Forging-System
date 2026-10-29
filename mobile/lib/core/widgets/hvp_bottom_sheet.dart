import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import 'hvp_button.dart';

/// Swipe-to-dismiss modal bottom sheet with a drag handle and optional title.
Future<T?> showHvpSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = sheetContext.hvp;
      final t = sheetContext.txt;
      return Container(
        decoration: ShapeDecoration(
          color: c.surface,
          shape: ChamferBorder(
            cut: 18,
            topLeft: true,
            topRight: true,
            bottomRight: false,
            side: BorderSide(color: c.borderStrong),
          ),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.borderStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(title.toUpperCase(), style: t.titleL),
                ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      );
    },
  );
}

/// Yes/no confirmation. Resolves to true only when the user confirms.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Huỷ',
  bool destructive = false,
}) async {
  final result = await showHvpSheet<bool>(
    context,
    title: title,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message, style: sheetContext.txt.body),
          const SizedBox(height: 20),
          destructive
              ? HvpButton.danger(label: confirmLabel, expand: true, onPressed: () => Navigator.of(sheetContext).pop(true))
              : HvpButton.primary(label: confirmLabel, expand: true, onPressed: () => Navigator.of(sheetContext).pop(true)),
          const SizedBox(height: 8),
          HvpButton.ghost(label: cancelLabel, expand: true, onPressed: () => Navigator.of(sheetContext).pop(false)),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// One row of a [showOptionSheet].
class SheetOption<T> {
  const SheetOption({required this.value, required this.label, this.icon, this.subtitle});

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
}

/// Lets the user pick one value from a short list.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  T? selected,
}) {
  return showHvpSheet<T>(
    context,
    title: title,
    builder: (sheetContext) {
      final c = sheetContext.hvp;
      final t = sheetContext.txt;
      // Material ancestor so ListTile ink shows above the sheet's decorated container.
      return Material(
        type: MaterialType.transparency,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: <Widget>[
            for (final option in options)
              ListTile(
                leading: option.icon == null ? null : Icon(option.icon, color: c.gold),
                title: Text(option.label, style: t.bodyL),
                subtitle: option.subtitle == null ? null : Text(option.subtitle!, style: t.bodySmall),
                trailing: option.value == selected ? Icon(HvpIcons.checkCircle, color: c.gold) : null,
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
          ],
        ),
      );
    },
  );
}
