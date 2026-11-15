import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/member_rules.dart';
import '../../../membership/domain/membership_models.dart';
import '../reception_memberships_providers.dart';

/// Step 1 of the manual activation: choose a package. Resolves to it, or null when dismissed.
Future<PackageType?> showPackagePicker(BuildContext context) =>
    showHvpSheet<PackageType>(context,
        title: 'Kích hoạt / gia hạn gói',
        builder: (_) => const _PackagePicker());

class _PackagePicker extends ConsumerStatefulWidget {
  const _PackagePicker();

  @override
  ConsumerState<_PackagePicker> createState() => _PackagePickerState();
}

class _PackagePickerState extends ConsumerState<_PackagePicker> {
  PackageType? _picked;

  @override
  Widget build(BuildContext context) => AsyncBody<List<PackageType>>(
        value: ref.watch(packageTypesProvider),
        onRetry: () => ref.invalidate(packageTypesProvider),
        builder: (context, packages) {
          if (packages.isEmpty) {
            return const EmptyState(
                icon: HvpIcons.ticket,
                title: 'Chưa có gói nào',
                message: 'Hiện chưa có gói nào đang bán.');
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              for (final p in packages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HvpCard(
                    highlighted: _picked?.id == p.id,
                    onTap: () => setState(() => _picked = p),
                    semanticLabel: p.name,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(p.name, style: context.txt.titleS),
                              Text(packageTypeSummary(p),
                                  style: context.txt.bodySmall),
                              if (p.hasClasses)
                                Text('${p.classCount} lớp để chọn',
                                    style: context.txt.caption),
                            ],
                          ),
                        ),
                        if (p.isTrial)
                          const StatusChip(
                              label: 'Gói trải nghiệm', tone: ChipTone.info),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              HvpButton.primary(
                  label: 'Tiếp tục',
                  expand: true,
                  onPressed: _picked == null
                      ? null
                      : () => Navigator.of(context).pop(_picked)),
            ],
          );
        },
      );
}
