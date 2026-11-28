import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/expandable_text.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
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
    final coach = item.coachName;
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
              IconLabel(icon: HvpIcons.event, label: eyebrow, style: t.label),
              const SizedBox(height: 4),
              IconLabel(
                  icon: HvpIcons.clock,
                  label: formatTimeRange(item.startsAt, item.endsAt),
                  style: t.label),
              const SizedBox(height: 8),
              ExpandableText(item.displayTitle, style: t.titleL),
              if (coach != null) ...<Widget>[
                const SizedBox(height: 6),
                IconLabel(icon: HvpIcons.glove, label: coach),
              ],
              if (item.branchName.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                IconLabel(icon: HvpIcons.mapPin, label: item.branchName),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  StatusChip(
                      label: item.sessionType.label,
                      tone: ChipTone.gold,
                      icon: HvpIcons.book),
                  if (item.isExam)
                    const StatusChip(
                        label: 'Kiểm tra',
                        tone: ChipTone.warning,
                        icon: HvpIcons.exam),
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
                IconLabel(
                    icon: HvpIcons.checkCircle,
                    iconSize: 18,
                    label: 'Đã check-in lúc ${formatTime(checkin)}',
                    style: t.body),
              ],
              if (status.isConfirmed && percent != null) ...<Widget>[
                const SizedBox(height: 6),
                IconLabel(
                    icon: HvpIcons.checks,
                    iconSize: 18,
                    label: 'Hoàn thành $percent%',
                    style: t.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        HvpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconLabel(
                  icon: HvpIcons.lesson,
                  iconSize: 18,
                  label: 'GIÁO ÁN',
                  style: t.label),
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
                IconLabel(
                    icon: HvpIcons.note,
                    iconSize: 18,
                    label: 'Ghi chú',
                    style: t.label),
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
