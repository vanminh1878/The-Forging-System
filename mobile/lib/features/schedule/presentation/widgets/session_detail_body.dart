import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import 'session_status_style.dart';

/// Hero, status, check-in/completion, lesson plan and notes of one session.
class SessionDetailBody extends StatelessWidget {
  const SessionDetailBody({super.key, required this.detail});

  final SessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final item = detail.item;
    final day = parseIsoDay(item.date);
    final eyebrow = day == null
        ? item.date
        : '${weekdayLong(day.weekday)}, ${formatCalendarDate(item.date)}';
    final sub = <String>[
      if (item.coachName != null) item.coachName!,
      if (item.branchName.isNotEmpty) item.branchName,
    ].join(' · ');
    final status = item.status;
    final description = status == SessionStatus.upcoming && item.isToday
        ? 'Hôm nay'
        : status.description;
    final checkin = item.checkinAt;
    final percent = item.completionPercent;
    final notes = detail.notes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        HvpCard(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$eyebrow · ${formatTimeRange(item.startsAt, item.endsAt)}',
                  style: t.label),
              const SizedBox(height: 6),
              Text(item.displayTitle, style: t.titleL),
              if (sub.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(sub, style: t.bodySmall)
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  StatusChip(
                      label: item.sessionType.label, tone: ChipTone.gold),
                  if (item.isExam)
                    const StatusChip(label: 'Kiểm tra', tone: ChipTone.warning),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HvpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SessionStatusChip(status: status),
                  const SizedBox(width: 10),
                  Expanded(child: Text(description, style: t.body)),
                ],
              ),
              if (checkin != null) ...<Widget>[
                const SizedBox(height: 10),
                _Line(
                    icon: HvpIcons.checkCircle,
                    text: 'Đã check-in lúc ${formatTime(checkin)}'),
              ],
              if (status.isConfirmed && percent != null) ...<Widget>[
                const SizedBox(height: 6),
                _Line(icon: HvpIcons.checks, text: 'Hoàn thành $percent%'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        HvpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('GIÁO ÁN', style: t.label),
              const SizedBox(height: 6),
              Text(
                  detail.lessonPlanTitle ??
                      'Buổi này chưa có giáo án chi tiết.',
                  style: t.bodyL),
            ],
          ),
        ),
        if (notes != null) ...<Widget>[
          const SizedBox(height: 12),
          HvpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Ghi chú', style: t.label),
                const SizedBox(height: 6),
                Text(notes, style: t.body),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: c.gold),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.txt.body)),
      ],
    );
  }
}
