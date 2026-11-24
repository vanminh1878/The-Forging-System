import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/status_chip.dart';

/// Shared Challenge identity block. Screens supply their workflow-specific
/// status label/tone and render progress/actions below this common summary.
class ChallengeSummaryHeader extends StatelessWidget {
  const ChallengeSummaryHeader({
    super.key,
    required this.typeLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.title,
    this.description,
  });

  final String typeLabel;
  final String statusLabel;
  final ChipTone statusTone;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatusChip(label: typeLabel, tone: ChipTone.gold),
              StatusChip(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: context.txt.titleS),
          if (description?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 4),
            Text(description!, style: context.txt.bodySmall),
          ],
        ],
      );
}
