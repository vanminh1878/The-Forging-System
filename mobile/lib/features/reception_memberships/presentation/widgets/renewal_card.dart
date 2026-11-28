import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/renewal_models.dart';

/// One renewal request: who, which package at what price, and the actions when it is pending.
class RenewalCard extends StatelessWidget {
  const RenewalCard(
      {super.key, required this.request, this.actions = const <Widget>[]});

  final RenewalRequest request;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final contact = <String>[
      if (request.memberPhone != null) request.memberPhone!,
      request.memberCode
    ].where((p) => p.isNotEmpty).join(' · ');
    final price =
        request.priceVnd == null ? null : '${formatInt(request.priceVnd!)}đ';
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(request.memberName, style: t.titleS)),
              StatusChip(
                  label: renewalStatusLabels[request.status] ?? request.status,
                  tone: _tone(request.status),
                  icon: switch (request.status) {
                    'COMPLETED' => HvpIcons.checkCircle,
                    'CANCELLED' => HvpIcons.xCircle,
                    _ => HvpIcons.hourglass,
                  }),
            ],
          ),
          if (contact.isNotEmpty)
            IconLabel(icon: HvpIcons.phone, label: contact),
          const SizedBox(height: 8),
          IconLabel(
              icon: HvpIcons.lesson,
              label: <String>[request.packageName, if (price != null) price]
                  .join(' · '),
              style: t.body),
          if (request.currentPackageName != null)
            IconLabel(
              icon: HvpIcons.ticket,
              label: 'Gói hiện tại: ${request.currentPackageName}'
                  '${request.currentEndDate == null ? '' : ' · hết hạn ${formatCalendarDate(request.currentEndDate!)}'}',
            ),
          if (request.note != null)
            IconLabel(icon: HvpIcons.note, label: 'Ghi chú: ${request.note}'),
          if (request.reason != null)
            IconLabel(
                icon: HvpIcons.xCircle, label: 'Lý do huỷ: ${request.reason}'),
          if (request.createdAt != null)
            IconLabel(
                icon: HvpIcons.send,
                label: 'Gửi ${formatDateTime(request.createdAt!)}',
                style: t.caption),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...actions
          ],
        ],
      ),
    );
  }

  static ChipTone _tone(String status) => switch (status) {
        'COMPLETED' => ChipTone.success,
        'CANCELLED' => ChipTone.danger,
        _ => ChipTone.warning,
      };
}
