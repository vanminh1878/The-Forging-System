import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../domain/course.dart';
import 'course_providers.dart';
import 'widgets/course_progress_bar.dart';

/// Student roadmap screen.
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: HvpAppBar(title: 'Lộ trình khóa học', titleIcon: HvpIcons.route),
        body: CourseRoadmap(),
      );
}

/// The five courses (BOOK I..V) in order, with progress. Body only, so the
/// schedule tab can show it as its "Giáo án" section.
class CourseRoadmap extends ConsumerWidget {
  const CourseRoadmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return AsyncBody<List<Course>>(
      value: courses,
      onRetry: () => ref.invalidate(coursesProvider),
      builder: (context, items) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          await ref.read(coursesProvider.future);
        },
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  EmptyState(
                    icon: HvpIcons.book,
                    title: 'Chưa có khóa học',
                    message: 'Lộ trình khóa học sẽ xuất hiện ở đây.',
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, HvpLayout.navClearance),
                itemCount: items.length,
                itemBuilder: (context, i) => _RoadmapStep(
                  number: i + 1,
                  course: items[i],
                  isLast: i == items.length - 1,
                ),
              ),
      ),
    );
  }
}

/// One course on the roadmap: numbered medallion on a vertical line, then the card.
class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep(
      {required this.number, required this.course, required this.isLast});

  final int number;
  final Course course;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final done = course.progress.status == CourseStatus.completed;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Column(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? c.emerald : c.goldSoft,
                    border: Border.all(
                        color: done ? c.emerald : c.gold.fade(0.6)),
                  ),
                  child: done
                      ? Icon(HvpIcons.check, size: 18, color: c.onGold)
                      : Text('$number',
                          style: t.titleS.copyWith(color: c.gold)),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: c.border)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CourseCard(course: course),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final c = context.hvp;
    return HvpCard(
      semanticLabel: 'Mở khóa ${course.name}',
      accent: course.progress.status == CourseStatus.inProgress ? c.gold : null,
      onTap: () => context.push(StudentPaths.course(course.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(course.name, style: t.titleM)),
              CourseStatusChip(status: course.progress.status),
            ],
          ),
          if (course.description != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(course.description!, style: t.bodySmall),
          ],
          const SizedBox(height: 6),
          IconLabel(
              icon: HvpIcons.lesson,
              label:
                  '${course.durationWeeks} tuần · ${course.totalLessons} bài',
              style: t.caption),
          const SizedBox(height: 12),
          CourseProgressBar(course: course),
        ],
      ),
    );
  }
}
