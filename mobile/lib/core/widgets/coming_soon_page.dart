import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../design/hvp_layout.dart';
import '../design/tape_divider.dart';
import 'hvp_app_bar.dart';
import 'hvp_card.dart';
import 'status_chip.dart';

/// Marked placeholder for a screen another engineer will implement.
///
/// Replace it by editing ONLY the matching line in `lib/app/routes/<role>_routes.dart`.
/// Use [standalone] for pushed sub-screens (adds its own app bar); tab pages
/// are body-only because the role shell already provides the app bar.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.owner,
    this.description,
    this.icon,
    this.action,
    this.standalone = false,
  });

  /// Vietnamese screen name, e.g. "Lịch tập".
  final String title;

  /// Owner hint, e.g. "feature: schedule".
  final String owner;
  final String? description;
  final IconData? icon;

  /// Optional widget under the description (e.g. a temporary entry button).
  final Widget? action;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, HvpLayout.navClearance),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: HvpLayout.maxContentWidth),
          child: HvpCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const TapeDivider(),
                const SizedBox(height: 20),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.goldSoft,
                    border: Border.all(color: c.gold.fade(0.5), width: 1.5),
                  ),
                  child: Icon(icon ?? HvpIcons.wrench, size: 32, color: c.gold),
                ),
                const SizedBox(height: 16),
                const StatusChip(label: 'Sắp ra mắt', tone: ChipTone.gold, icon: HvpIcons.hourglass),
                const SizedBox(height: 12),
                Text(title.toUpperCase(), style: t.titleL, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  description ?? 'Màn hình này đang được xây dựng.',
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...<Widget>[const SizedBox(height: 16), action!],
                const SizedBox(height: 14),
                Text('Phụ trách: $owner', style: t.mono.copyWith(color: c.textMuted, fontSize: 12)),
                const SizedBox(height: 20),
                const TapeDivider(),
              ],
            ),
          ),
        ),
      ),
    );
    if (!standalone) return body;
    return Scaffold(appBar: HvpAppBar(title: title), body: body);
  }
}
