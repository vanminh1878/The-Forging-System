import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hvp_context.dart';
import 'hvp_text_field.dart';

/// A whole-number limit (capacity, seats...) with an explicit "no limit" switch,
/// so an empty box never has to mean "unlimited". While [unlimited] the number
/// box is disabled and not validated; the caller sends `null` for no limit.
class HvpLimitField extends StatelessWidget {
  const HvpLimitField({
    super.key,
    required this.label,
    required this.unlimitedLabel,
    required this.controller,
    required this.unlimited,
    required this.onUnlimitedChanged,
    this.validator,
    this.focusNode,
    this.maxLength = 4,
    this.enabled = true,
  });

  final String label;

  /// Text of the switch, e.g. "Không giới hạn sĩ số".
  final String unlimitedLabel;
  final TextEditingController controller;
  final bool unlimited;
  final ValueChanged<bool> onUnlimitedChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final int maxLength;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Material ancestor so the tile's ink shows above a decorated sheet.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(unlimitedLabel, style: context.txt.body),
            value: unlimited,
            activeThumbColor: context.hvp.gold,
            onChanged: enabled ? onUnlimitedChanged : null,
          ),
        ),
        const SizedBox(height: 4),
        HvpTextField(
          label: label,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled && !unlimited,
          required: !unlimited,
          hint: unlimited ? 'Không giới hạn' : null,
          maxLength: maxLength,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ],
          validator: unlimited ? null : validator,
        ),
      ],
    );
  }
}
