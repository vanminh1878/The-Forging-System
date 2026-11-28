import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import 'session_status_style.dart';

/// One session on the calendar. Cancelled sessions are dimmed and struck through.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.item, this.onTap});

  final ScheduleItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final cancelled = item.status == SessionStatus.cancelled;
    final day = formatSessionDay(item.date);
    final coach = item.coachName;
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: HvpCard(
        onTap: onTap,
        accent: item.isToday ? c.gold : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The chip drops under the date rather than squeezing it.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  Text(item.isToday ? '$day · Hôm nay' : day, style: t.caption),
                  SessionStatusChip(status: item.status),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.displayTitle,
              style: t.titleS.copyWith(
                decoration: cancelled ? TextDecoration.lineThrough : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            IconLabel(
                icon: HvpIcons.clock,
                label: formatTimeRange(item.startsAt, item.endsAt)),
            if (coach != null) ...<Widget>[
              const SizedBox(height: 4),
              IconLabel(icon: HvpIcons.glove, label: coach),
            ],
            if (item.branchName.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              IconLabel(icon: HvpIcons.mapPin, label: item.branchName),
            ],
          ],
        ),
      ),
    );
  }
}
