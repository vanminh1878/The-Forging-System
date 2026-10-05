import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';

/// Labelled text field with consistent styling, optional password toggle.
class HvpTextField extends StatefulWidget {
  const HvpTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.obscure = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final bool obscure;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextAlign textAlign;

  @override
  State<HvpTextField> createState() => _HvpTextFieldState();
}

class _HvpTextFieldState extends State<HvpTextField> {
  late bool _hidden = widget.obscure;
  bool _focused = false;

  UnderlineInputBorder _border(Color color, {double width = 1.3}) => UnderlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.label.toUpperCase(), style: t.label.copyWith(color: _focused ? c.gold : c.textMuted, letterSpacing: 2.2)),
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: widget.obscure && _hidden,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            textAlign: widget.textAlign,
            style: t.bodyL,
            cursorColor: c.gold,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: t.body.copyWith(color: c.textMuted),
              helperText: widget.helper,
              helperStyle: t.caption,
              errorStyle: t.bodySmall.copyWith(color: c.red),
              counterText: '',
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, size: 20, color: _focused ? c.gold : c.textMuted),
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(_hidden ? HvpIcons.eye : HvpIcons.eyeSlash, size: 20, color: c.textMuted),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
              border: _border(c.borderStrong),
              enabledBorder: _border(c.borderStrong),
              disabledBorder: _border(c.border),
              focusedBorder: _border(c.gold, width: 1.8),
              errorBorder: _border(c.red),
              focusedErrorBorder: _border(c.red, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
