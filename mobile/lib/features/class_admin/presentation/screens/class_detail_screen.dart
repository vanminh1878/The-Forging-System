import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/expandable_text.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/hvp_sub_nav.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';
import '../widgets/class_form_sheet.dart';
import '../widgets/class_lesson_plan_section.dart';
import '../widgets/class_sessions_section.dart';
import '../widgets/enrol_member_sheet.dart';
import '../widgets/exam_session_sheet.dart';

/// CLS-08: one class, with its upcoming sessions, lesson plan and roster on
/// one sub tab each.
///
/// With [readOnly] (coach, reception) nothing can be changed: no edit, enrol,
/// remove, exam or cancel.
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen(
      {super.key, required this.classId, this.readOnly = false});

  final String classId;
  final bool readOnly;

  Future<void> _remove(
      BuildContext context, WidgetRef ref, RosterEntry m) async {
    final yes = await showConfirmSheet(context,
        title: 'Cho rời lớp',
        message: 'Cho ${m.fullName} rời lớp này?',
        confirmLabel: 'Cho rời lớp',
        destructive: true);
    if (!yes || !context.mounted) return;
    final ok = await ref.read(classSubmitProvider.notifier).run(() =>
        ref.read(classRepositoryProvider).removeMember(classId, m.memberId));
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(classDetailProvider(classId));
      ref.invalidate(classPageProvider);
      HvpToast.success(context, 'Đã cho học viên rời lớp.');
    } else {
      HvpToast.error(context,
          ref.read(classSubmitProvider).error ?? 'Không thể thực hiện.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(classDetailProvider(classId));
    return Scaffold(
      appBar:
          const HvpAppBar(title: 'Chi tiết lớp', titleIcon: HvpIcons.usersFill),
      body: AsyncBody<ClassDetail>(
        value: detail,
        onRetry: () => ref.invalidate(classDetailProvider(classId)),
        builder: (_, d) {
          final c = d.summary;
          Future<void> refresh() {
            ref.invalidate(classSessionsProvider(classId));
            final courseId = c.courseId;
            if (courseId != null) {
              ref.invalidate(courseDetailProvider(courseId));
            }
            return ref.refresh(classDetailProvider(classId).future);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _Header(summary: c, readOnly: readOnly),
              ),
              Expanded(
                child: HvpSubTabs(
                  items: const <HvpSubNavItem>[
                    HvpSubNavItem(label: 'Buổi tập', icon: HvpIcons.calendar),
                    HvpSubNavItem(label: 'Giáo án', icon: HvpIcons.lesson),
                    HvpSubNavItem(label: 'Học viên', icon: HvpIcons.users),
                  ],
                  children: <Widget>[
                    _Section(
                        onRefresh: refresh, children: _sessions(context, c)),
                    _Section(
                      onRefresh: refresh,
                      children: <Widget>[
                        ClassLessonPlanSection(courseId: c.courseId),
                      ],
                    ),
                    _Section(
                        onRefresh: refresh, children: _roster(context, ref, d)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _sessions(BuildContext context, ClassSummary c) => <Widget>[
        if (!readOnly)
          HvpButton.secondary(
              label: 'Tạo buổi kiểm tra',
              icon: HvpIcons.calendarCheck,
              expand: true,
              // The server also refuses it (CLASS_INACTIVE); this only explains why.
              onPressed: c.isActive
                  ? () => showExamSheet(context,
                      classId: classId, className: c.name)
                  : null),
        if (!readOnly && !c.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: IconLabel(
                icon: HvpIcons.info,
                iconColor: context.hvp.amber,
                label: 'Lớp đã ngừng hoạt động, không tạo được buổi kiểm tra.',
                style:
                    context.txt.bodySmall.copyWith(color: context.hvp.amber)),
          ),
        ClassSessionsSection(classId: classId, readOnly: readOnly),
      ];

  List<Widget> _roster(BuildContext context, WidgetRef ref, ClassDetail d) {
    final t = context.txt;
    return <Widget>[
      SectionHeader(
          title: 'Học viên (${d.roster.length})',
          icon: HvpIcons.users,
          padding: const EdgeInsets.only(bottom: 10)),
      if (!readOnly) ...<Widget>[
        HvpButton.primary(
            label: 'Thêm học viên vào lớp',
            icon: HvpIcons.userPlus,
            expand: true,
            onPressed: () => showEnrolSheet(context, classId)),
        const SizedBox(height: 10),
      ],
      if (d.roster.isEmpty)
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Lớp chưa có học viên.', style: t.bodySmall)),
      for (final m in d.roster)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HvpCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                HvpAvatar(name: m.fullName, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(m.fullName,
                          style: t.bodyL,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      IconLabel(icon: HvpIcons.idCard, label: m.memberCode),
                    ],
                  ),
                ),
                if (!readOnly)
                  IconButton(
                      tooltip: 'Cho rời lớp',
                      icon: Icon(HvpIcons.trash, color: context.hvp.red),
                      onPressed: () => _remove(context, ref, m)),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Name, type, schedule and enrolment of the class.
class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.readOnly});

  final ClassSummary summary;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final c = summary;
    return HvpCard(
      highlighted: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  child: ExpandableText(c.name, style: t.titleM, maxLines: 2)),
              if (!readOnly)
                IconButton(
                    tooltip: 'Sửa lớp',
                    icon: Icon(HvpIcons.pencil, color: context.hvp.gold),
                    onPressed: () => showClassForm(context, existing: c)),
            ],
          ),
          const SizedBox(height: 4),
          IconLabel(
              icon: HvpIcons.book, label: sessionTypeLabel(c.sessionTypeCode)),
          const SizedBox(height: 3),
          IconLabel(
              icon: HvpIcons.eventRepeat,
              label:
                  '${weekdaysLabel(c.weekdays)} · ${c.startTime} · ${c.durationMinutes} phút'),
          const SizedBox(height: 3),
          IconLabel(
              icon: HvpIcons.users,
              label:
                  '${enrolmentLabel(c.enrolledCount, c.capacity)} học viên${c.isActive ? '' : ' · Đã ngừng'}'),
        ],
      ),
    );
  }
}

/// One sub tab: a pull-to-refresh list.
class _Section extends StatelessWidget {
  const _Section({required this.onRefresh, required this.children});

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HvpRefresh(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, HvpLayout.navClearance),
          children: children,
        ),
      );
}
