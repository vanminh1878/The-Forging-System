import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/course.dart';
import '../domain/lesson_sections.dart';
import 'course_providers.dart';

/// One lesson: where it sits in the course, its objectives and the session plan.
class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.courseId, required this.lessonNo});

  final String courseId;
  final int lessonNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (courseId: courseId, lessonNo: lessonNo);
    final lesson = ref.watch(lessonProvider(key));
    // Already cached when the learner came from the course screen; only adds the course name.
    final courseName = ref.watch(courseDetailProvider(courseId)).valueOrNull?.course.name;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Bài học', titleIcon: HvpIcons.lesson),
      body: AsyncBody<Lesson>(
        value: lesson,
        onRetry: () => ref.invalidate(lessonProvider(key)),
        builder: (context, data) {
          final sections = lessonSections(data);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(lessonProvider(key));
              await ref.read(lessonProvider(key).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, HvpLayout.navClearance),
              children: <Widget>[
                _LessonHeader(lesson: data, courseName: courseName),
                for (final section in sections) _SectionBlock(section: section),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.lesson, this.courseName});

  final Lesson lesson;
  final String? courseName;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final s = lesson.summary;
    final where = <String>[
      if (courseName != null) courseName!,
      if (s.weekNo != null) 'Tuần ${s.weekNo}',
      'Bài ${s.lessonNo}',
    ].join(' · ');
    return HvpCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconLabel(icon: HvpIcons.book, label: where.toUpperCase(), style: t.label.copyWith(color: c.gold)),
          const SizedBox(height: 6),
          Semantics(header: true, child: Text(s.title, style: t.titleL)),
          if (s.subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(s.subtitle!, style: t.bodySmall),
          ],
          if (s.isAssessment || s.isGraduation || s.isAdvanced) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (s.isAssessment) const StatusChip(label: 'Kiểm tra', tone: ChipTone.info, icon: HvpIcons.exam),
                if (s.isGraduation) const StatusChip(label: 'Tốt nghiệp', tone: ChipTone.warning, icon: HvpIcons.crown),
                if (s.isAdvanced) const StatusChip(label: 'Nâng cao', icon: HvpIcons.star),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final LessonSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: section.title, icon: HvpIcons.objective),
        if (section.text != null) Text(section.text!, style: t.body),
        for (final (i, item) in section.items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.goldSoft,
                    border: Border.all(color: c.gold.fade(0.5)),
                  ),
                  child: section.numbered
                      ? Text('${i + 1}', style: t.caption.copyWith(color: c.gold))
                      : Icon(Icons.circle, size: 6, color: c.gold),
                ),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(item, style: t.body))),
              ],
            ),
          ),
      ],
    );
  }
}
