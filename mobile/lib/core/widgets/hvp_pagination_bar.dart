import 'package:flutter/material.dart';

import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';

/// Reusable pagination bar: "Trang trước" / "Trang sau" with caret icons.
/// Hides itself entirely when [totalPages] is 1 or less.
class HvpPaginationBar extends StatelessWidget {
  const HvpPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          TextButton.icon(
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(HvpIcons.caretLeft),
            label: const Text('Trang trước'),
          ),
          Text('$page / $totalPages', style: context.txt.caption),
          TextButton.icon(
            onPressed:
                page < totalPages ? () => onPageChanged(page + 1) : null,
            icon: const Icon(HvpIcons.caretRight),
            label: const Text('Trang sau'),
          ),
        ],
      ),
    );
  }
}
