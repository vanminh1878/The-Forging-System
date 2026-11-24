import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/chamfer_border.dart';
import '../../core/design/hvp_context.dart';
import '../../core/design/hvp_icons.dart';
import '../../core/design/theme_mode_controller.dart';

/// Two-way switch: Sáng / Tối.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  static const List<(ThemeMode, String, IconData)> _options =
      <(ThemeMode, String, IconData)>[
    (ThemeMode.light, 'Sáng', HvpIcons.sun),
    (ThemeMode.dark, 'Tối', HvpIcons.moon),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hvp;
    final t = context.txt;
    final mode = ref.watch(themeModeProvider);
    return Row(
      children: <Widget>[
        for (var i = 0; i < _options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              label: _options[i].$2,
              icon: _options[i].$3,
              selected: mode == _options[i].$1,
              onTap: () =>
                  ref.read(themeModeProvider.notifier).setMode(_options[i].$1),
              colors: (
                c.gold,
                c.onGold,
                c.surfaceHigh,
                c.borderStrong,
                c.textSecondary
              ),
              style: t.titleS,
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.style,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// (selected fill, selected foreground, idle fill, idle border, idle foreground)
  final (Color, Color, Color, Color, Color) colors;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? colors.$2 : colors.$5;
    final shape = ChamferBorder(
        cut: 8, side: BorderSide(color: selected ? colors.$1 : colors.$4));
    return Semantics(
      button: true,
      selected: selected,
      label: 'Giao diện $label',
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.$1 : colors.$3,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 2),
                Text(label.toUpperCase(),
                    style: style.copyWith(color: fg, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact Sáng / Tối switch for screens without the account sheet (sign-in, register).
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hvp;
    final mode = ref.watch(themeModeProvider);
    Widget segment(ThemeMode value, IconData icon, String label) {
      final selected = mode == value;
      return Semantics(
        button: true,
        selected: selected,
        label: 'Giao diện $label',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => ref.read(themeModeProvider.notifier).setMode(value),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
            decoration: BoxDecoration(
              color: selected ? c.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child:
                Icon(icon, size: 20, color: selected ? c.onGold : c.textMuted),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.borderStrong),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            segment(ThemeMode.light, HvpIcons.sun, 'Sáng'),
            segment(ThemeMode.dark, HvpIcons.moon, 'Tối'),
          ],
        ),
      ),
    );
  }
}
