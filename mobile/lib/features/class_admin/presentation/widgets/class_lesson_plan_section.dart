import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/shimmer_box.dart';
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
        const SectionHeader(title: 'Giáo án / bài học'),
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
                  Text(detail.course.name, style: t.titleS),
                  for (final week in detail.lessonsByWeek.entries) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                          week.key == 0 ? 'Chưa xếp tuần' : 'Tuần ${week.key}',
                          style: t.label),
                    ),
                    for (final lesson in week.value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Bài ${lesson.lessonNo} · ${lesson.title}',
                            style: t.body),
                        subtitle: lesson.subtitle == null
                            ? null
                            : Text(lesson.subtitle!, style: t.bodySmall),
                        trailing: lesson.isAssessment
                            ? Text('Kiểm tra', style: t.caption)
                            : null,
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
