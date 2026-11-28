import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../membership/domain/membership_models.dart';
import '../../../membership/domain/membership_rules.dart';

/// One package of the learner (running or waiting) with an optional cancel button.
class PackagePanel extends StatelessWidget {
  const PackagePanel(
      {super.key,
      required this.title,
      required this.package,
      this.cancelLabel,
      this.onCancel});

  final String title;
  final MemberPackage package;
  final String? cancelLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final days = daysRemainingLabel(package.daysRemaining);
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: IconLabel(
                      icon: HvpIcons.ticket,
                      label: title.toUpperCase(),
                      style: t.label)),
              if (package.endingSoon)
                const StatusChip(
                    label: 'Sắp hết hạn',
                    tone: ChipTone.warning,
                    icon: HvpIcons.warning),
            ],
          ),
          const SizedBox(height: 4),
          IconLabel(
              icon: HvpIcons.lesson, label: package.name, style: t.titleS),
          const SizedBox(height: 3),
          IconLabel(
              icon: HvpIcons.dateRange,
              label: <String>[validityLabel(package), if (days != null) days]
                  .join(' · ')),
          const SizedBox(height: 3),
          IconLabel(icon: HvpIcons.barbell, label: sessionsLabel(package)),
          if (onCancel != null && cancelLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            HvpButton.danger(
                label: cancelLabel!,
                icon: HvpIcons.xCircle,
                small: true,
                expand: true,
                onPressed: onCancel),
          ],
        ],
      ),
    );
  }
}
