import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hvp_icons.dart';
import '../utils/time_input.dart';
import 'hvp_text_field.dart';

/// HH:mm field: type digits (the colon is inserted, letters are blocked) or tap
/// the clock to open the time picker.
class HvpTimeField extends StatelessWidget {
  const HvpTimeField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool required;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          parseHm(controller.text) ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    controller.text = formatHm(picked);
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        HvpTextField(
          label: label,
          hint: 'HH:mm',
          controller: controller,
          required: required,
          enabled: enabled,
          focusNode: focusNode,
          textInputAction: textInputAction,
          keyboardType: TextInputType.number,
          maxLength: 5,
          inputFormatters: const <TextInputFormatter>[HmInputFormatter()],
          suffixIcon: HvpIcons.clock,
          validator: validator,
          onChanged: onChanged,
        ),
        Positioned(
          right: 0,
          top: 0,
          width: 48,
          height: 52,
          child: Semantics(
            button: true,
            label: 'Chọn giờ',
            excludeSemantics: true,
            child: InkResponse(
              onTap: enabled ? () => _pick(context) : null,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
