import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../domain/rank_rules.dart';

/// "Điều kiện lên hạng" checklist (DP, time, courses, trial).
class RequirementsCard extends StatelessWidget {
  const RequirementsCard({super.key, required this.requirements});

  final List<Requirement> requirements;

  @override
  Widget build(BuildContext context) {
    return HvpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < requirements.length; i++) ...<Widget>[
            if (i > 0) const Divider(),
            _RequirementRow(requirement: requirements[i]),
          ],
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement});

  final Requirement requirement;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final met = requirement.met;
    final color = met ? c.emerald : c.textMuted;
    return Semantics(
      label: '${requirement.title}: ${met ? 'đã đạt' : 'chưa đạt'}. ${requirement.detail}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(met ? HvpIcons.checkCircle : HvpIcons.hourglass, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(requirement.title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(requirement.detail, style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
