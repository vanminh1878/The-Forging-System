import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../courses/domain/course.dart';
import '../../../courses/presentation/course_providers.dart';

/// Read-only lesson plan of the course a class follows: lessons grouped by week.
class ClassLessonPlanSection extends ConsumerWidget {
  const ClassLessonPlanSection({super.key, required this.courseId});

  /// Null when the class is not attached to a course.
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final id = courseId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
            title: 'Giáo án / bài học',
            icon: HvpIcons.lesson,
            padding: EdgeInsets.only(top: 8, bottom: 10)),
        if (id == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Lớp chưa gắn khóa học nên chưa có giáo án.',
                style: t.bodySmall),
          )
        else
          AsyncBody<CourseDetail>(
            value: ref.watch(courseDetailProvider(id)),
            onRetry: () => ref.invalidate(courseDetailProvider(id)),
            loading:
                const SizedBox(height: 180, child: ShimmerList(itemCount: 2)),
            builder: (_, detail) {
              if (detail.lessons.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      Text('Khóa học chưa có bài học nào.', style: t.bodySmall),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  IconLabel(
                      icon: HvpIcons.crown,
                      iconSize: 18,
                      label: detail.course.name,
                      style: t.titleS),
                  for (final week in detail.lessonsByWeek.entries) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: IconLabel(
                          icon: HvpIcons.dateRange,
                          label: week.key == 0
                              ? 'Chưa xếp tuần'
                              : 'Tuần ${week.key}',
                          style: t.label),
                    ),
                    for (final lesson in week.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: HvpCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              IconLabel(
                                  icon: HvpIcons.barbell,
                                  iconSize: 18,
                                  label:
                                      'Bài ${lesson.lessonNo} · ${lesson.title}',
                                  style: t.body),
                              if (lesson.subtitle != null) ...<Widget>[
                                const SizedBox(height: 4),
                                IconLabel(
                                    icon: HvpIcons.objective,
                                    label: lesson.subtitle!),
                              ],
                              if (lesson.isAssessment) ...<Widget>[
                                const SizedBox(height: 8),
                                const StatusChip(
                                    label: 'Kiểm tra',
                                    tone: ChipTone.warning,
                                    icon: HvpIcons.exam),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
