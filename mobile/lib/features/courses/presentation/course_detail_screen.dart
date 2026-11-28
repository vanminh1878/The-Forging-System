import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/course.dart';
import 'course_providers.dart';
import 'widgets/course_progress_bar.dart';

/// One course: its progress and the lessons grouped by week.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(courseDetailProvider(courseId));
    return Scaffold(
      appBar: const HvpAppBar(title: 'Khóa học', titleIcon: HvpIcons.book),
      body: AsyncBody<CourseDetail>(
        value: detail,
        onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(courseDetailProvider(courseId));
            await ref.read(courseDetailProvider(courseId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, HvpLayout.navClearance),
            children: <Widget>[
              _CourseHeader(course: data.course),
              if (data.lessons.isEmpty)
                const EmptyState(
                  icon: HvpIcons.book,
                  title: 'Chưa có bài học',
                  message: 'Khóa này chưa có bài học nào.',
                ),
              for (final week in data.lessonsByWeek.entries) ...<Widget>[
                SectionHeader(
                    title: week.key == 0 ? 'Bài học khác' : 'Tuần ${week.key}',
                    icon: HvpIcons.dateRange),
                for (final lesson in week.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LessonTile(
                      courseId: data.course.id,
                      lesson: lesson,
                      state: _stateOf(data.course.progress, lesson.lessonNo),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _LessonState { done, next, todo }

/// Lessons are taken in order, so the first `lessonsCompleted` ones are done
/// and the one after them is next (the backend keeps only a counter).
_LessonState _stateOf(CourseProgress progress, int lessonNo) {
  if (progress.status == CourseStatus.completed || lessonNo <= progress.lessonsCompleted) return _LessonState.done;
  if (lessonNo == progress.lessonsCompleted + 1) return _LessonState.next;
  return _LessonState.todo;
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return HvpCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(course.name, style: t.titleL)),
              CourseStatusChip(status: course.progress.status),
            ],
          ),
          if (course.description != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(course.description!, style: t.bodySmall),
          ],
          const SizedBox(height: 6),
          IconLabel(icon: HvpIcons.lesson, label: '${course.durationWeeks} tuần · ${course.totalLessons} bài', style: t.caption),
          const SizedBox(height: 12),
          CourseProgressBar(course: course),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.courseId, required this.lesson, required this.state});

  final String courseId;
  final LessonSummary lesson;
  final _LessonState state;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final done = state == _LessonState.done;
    return HvpCard(
      semanticLabel: 'Bài ${lesson.lessonNo}: ${lesson.title}',
      accent: state == _LessonState.next ? c.gold : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push(StudentPaths.courseLesson(courseId, lesson.lessonNo)),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? c.emerald : c.surfaceHigh,
              border: Border.all(color: done ? c.emerald : c.border),
            ),
            child: done
                ? Icon(HvpIcons.check, size: 18, color: c.onGold)
                : Text('${lesson.lessonNo}', style: t.labelStrong.copyWith(color: c.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(lesson.title, style: t.titleS),
                if (lesson.subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(lesson.subtitle!, style: t.caption),
                ],
                if (_chips.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: _chips),
                ],
              ],
            ),
          ),
          Icon(HvpIcons.caretRight, color: c.textMuted),
        ],
      ),
    );
  }

  List<Widget> get _chips => <Widget>[
        if (state == _LessonState.next) const StatusChip(label: 'Tiếp theo', tone: ChipTone.gold, icon: HvpIcons.play),
        if (lesson.isAssessment) const StatusChip(label: 'Kiểm tra', tone: ChipTone.info, icon: HvpIcons.exam),
        if (lesson.isGraduation) const StatusChip(label: 'Tốt nghiệp', tone: ChipTone.warning, icon: HvpIcons.crown),
        if (lesson.isAdvanced) const StatusChip(label: 'Nâng cao', icon: HvpIcons.star),
      ];
}
