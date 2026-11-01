import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_card.dart';
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.isToday ? '$day · Hôm nay' : day, style: t.caption),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      item.displayTitle,
                      formatTimeRange(item.startsAt, item.endsAt),
                      if (coach != null) coach,
                    ].join(' · '),
                    style: t.titleS.copyWith(
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.branchName.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(item.branchName, style: t.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SessionStatusChip(status: item.status),
          ],
        ),
      ),
    );
  }
}
