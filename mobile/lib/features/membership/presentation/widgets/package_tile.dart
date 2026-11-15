import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';

/// One package of the picker: name, trial tag, summary and price.
class PackageTile extends StatelessWidget {
  const PackageTile({
    super.key,
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final PackageType package;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpCard(
      accent: selected ? c.gold : null,
      highlighted: selected,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(package.name, style: t.titleS),
                if (package.isTrial) ...<Widget>[
                  const SizedBox(height: 4),
                  const StatusChip(
                      label: 'Gói trải nghiệm', tone: ChipTone.gold),
                ],
                const SizedBox(height: 4),
                Text(packageSummary(package), style: t.bodySmall),
                const SizedBox(height: 4),
                Text(priceLabel(package.priceVnd),
                    style: t.titleS.copyWith(color: c.gold)),
              ],
            ),
          ),
          if (selected) Icon(HvpIcons.checkCircle, color: c.gold),
        ],
      ),
    );
  }
}
