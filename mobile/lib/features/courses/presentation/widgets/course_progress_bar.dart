import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/course.dart';

/// Thin gold bar with "done / total bài" under it.
class CourseProgressBar extends StatelessWidget {
  const CourseProgressBar({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final done = course.progress.lessonsCompleted;
    return Semantics(
      label: 'Đã học $done trên ${course.totalLessons} bài',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: course.progressRatio,
              minHeight: 4,
              backgroundColor: c.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(c.gold),
            ),
          ),
          const SizedBox(height: 6),
          Text('$done / ${course.totalLessons} bài', style: t.caption),
        ],
      ),
    );
  }
}

/// Status pill of a course for the learner.
class CourseStatusChip extends StatelessWidget {
  const CourseStatusChip({super.key, required this.status});

  final CourseStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CourseStatus.completed:
        return const StatusChip(
            label: 'Hoàn thành',
            tone: ChipTone.success,
            icon: HvpIcons.checkCircle);
      case CourseStatus.inProgress:
        return const StatusChip(
            label: 'Đang học', tone: ChipTone.gold, icon: HvpIcons.play);
      case CourseStatus.notStarted:
        return const StatusChip(
            label: 'Chưa bắt đầu', icon: HvpIcons.hourglass);
    }
  }
}
