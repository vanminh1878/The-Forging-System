import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// One choice of a filter row: icon + label, filled when selected. Colours come
/// from the app's chip theme, so every filter in the app looks the same.
class HvpFilterChip extends StatelessWidget {
  const HvpFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: selected ? c.onSelected : c.gold),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
