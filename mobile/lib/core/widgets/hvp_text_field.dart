import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';

/// Labelled text field: floating label (sentence case, regular weight), filled
/// surface with a rounded outline, optional password toggle. [required] appends
/// the `*` marker to the label.
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
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
    this.obscure = false,
    this.required = false,
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
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;

  /// Trailing icon (e.g. a calendar or clock for picker fields). Ignored for password fields.
  final IconData? suffixIcon;
  final bool obscure;
  final bool required;
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
  final bool autofocus;

  @override
  State<HvpTextField> createState() => _HvpTextFieldState();
}

class _HvpTextFieldState extends State<HvpTextField> {
  late bool _hidden = widget.obscure;
  bool _focused = false;

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final label = widget.required ? '${widget.label} *' : widget.label;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscure && _hidden,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
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
          labelText: label,
          labelStyle: t.body.copyWith(color: c.textMuted),
          floatingLabelStyle:
              t.bodySmall.copyWith(color: _focused ? c.gold : c.textSecondary),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          hintText: widget.hint,
          hintStyle: t.body.copyWith(color: c.textMuted),
          helperText: widget.helper,
          helperMaxLines: 2,
          helperStyle: t.caption,
          errorMaxLines: 3,
          errorStyle: t.bodySmall.copyWith(color: c.red),
          counterText: '',
          filled: true,
          fillColor: widget.enabled ? c.surfaceHigh : c.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon,
                  size: 20, color: _focused ? c.gold : c.textMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 24),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(_hidden ? HvpIcons.eye : HvpIcons.eyeSlash,
                      size: 20, color: c.textMuted),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : widget.suffixIcon == null
                  ? null
                  : Icon(widget.suffixIcon, size: 20, color: c.textMuted),
          border: _border(c.borderStrong),
          enabledBorder: _border(c.borderStrong),
          disabledBorder: _border(c.border),
          focusedBorder: _border(c.gold, width: 1.8),
          errorBorder: _border(c.red),
          focusedErrorBorder: _border(c.red, width: 1.8),
        ),
      ),
    );
  }
}
