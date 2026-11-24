import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';
import '../widgets/class_form_sheet.dart';
import '../widgets/class_lesson_plan_section.dart';
import '../widgets/class_sessions_section.dart';
import '../widgets/enrol_member_sheet.dart';
import '../widgets/exam_session_sheet.dart';

/// CLS-08: one class with its roster; enrol and remove learners.
///
/// With [readOnly] (coach, reception) it only shows the class, its roster, the
/// upcoming sessions and the lesson plan: no edit, enrol, remove, exam or cancel.
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
    final t = context.txt;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Chi tiết lớp'),
      body: AsyncBody<ClassDetail>(
        value: detail,
        onRetry: () => ref.invalidate(classDetailProvider(classId)),
        builder: (_, d) {
          final c = d.summary;
          return HvpRefresh(
            onRefresh: () {
              ref.invalidate(classSessionsProvider(classId));
              return ref.refresh(classDetailProvider(classId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: <Widget>[
                HvpCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(children: <Widget>[
                          Expanded(child: Text(c.name, style: t.titleM)),
                          if (!readOnly)
                            IconButton(
                                tooltip: 'Sửa lớp',
                                icon: const Icon(HvpIcons.pencil),
                                onPressed: () =>
                                    showClassForm(context, existing: c)),
                        ]),
                        Text(
                            '${sessionTypeLabel(c.sessionTypeCode)} · ${weekdaysLabel(c.weekdays)} · ${c.startTime} · ${c.durationMinutes} phút',
                            style: t.body),
                        Text(
                            '${enrolmentLabel(c.enrolledCount, c.capacity)} học viên${c.isActive ? '' : ' · Đã ngừng'}',
                            style: t.bodySmall),
                      ]),
                ),
                const SizedBox(height: 12),
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
                    child: Row(children: <Widget>[
                      Icon(HvpIcons.info, size: 16, color: context.hvp.amber),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              'Lớp đã ngừng hoạt động, không tạo được buổi kiểm tra.',
                              style: t.bodySmall
                                  .copyWith(color: context.hvp.amber))),
                    ]),
                  ),
                ClassSessionsSection(classId: classId, readOnly: readOnly),
                if (readOnly) ClassLessonPlanSection(courseId: c.courseId),
                SectionHeader(title: 'Học viên (${d.roster.length})'),
                if (!readOnly)
                  HvpButton.primary(
                      label: 'Thêm học viên vào lớp',
                      icon: HvpIcons.userPlus,
                      expand: true,
                      onPressed: () => showEnrolSheet(context, classId)),
                const SizedBox(height: 8),
                if (d.roster.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Lớp chưa có học viên.', style: t.bodySmall)),
                for (final m in d.roster)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.fullName, style: t.bodyL),
                    subtitle: Text(m.memberCode, style: t.bodySmall),
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip: 'Cho rời lớp',
                            icon: Icon(HvpIcons.trash, color: context.hvp.red),
                            onPressed: () => _remove(context, ref, m)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
