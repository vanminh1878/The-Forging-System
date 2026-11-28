import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../class_providers.dart';

/// Upcoming sessions of a class, with cancel on those that can still be cancelled.
class ClassSessionsSection extends ConsumerWidget {
  const ClassSessionsSection(
      {super.key, required this.classId, this.readOnly = false});

  final String classId;

  /// Coach and reception only look at the sessions; cancelling is the admin's job here.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(classSessionsProvider(classId));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
              title: 'Buổi tập sắp tới',
              icon: HvpIcons.calendar,
              padding: EdgeInsets.only(top: 8, bottom: 10)),
          AsyncBody<List<ClassSession>>(
            value: sessions,
            onRetry: () => ref.invalidate(classSessionsProvider(classId)),
            loading: const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
            builder: (_, list) {
              if (list.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Chưa có buổi tập nào.',
                        style: context.txt.bodySmall));
              }
              return Column(children: <Widget>[
                for (final s in list)
                  _SessionRow(session: s, classId: classId, readOnly: readOnly),
              ]);
            },
          ),
        ]);
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow(
      {required this.session, required this.classId, required this.readOnly});

  final ClassSession session;
  final String classId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancellable = !readOnly &&
        canCancelSession(session.status, session.startsAt, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HvpCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The chip drops under the date rather than squeezing it.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  IconLabel(
                      icon: HvpIcons.event,
                      iconSize: 18,
                      label: formatDateTime(session.startsAt),
                      style: context.txt.bodyL),
                  StatusChip(
                      label: _statusLabel(session.status),
                      tone: _statusTone(session.status),
                      icon: _statusIcon(session.status)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            IconLabel(icon: HvpIcons.lesson, label: session.title, maxLines: 2),
            if (session.coachName != null) ...<Widget>[
              const SizedBox(height: 3),
              IconLabel(
                  icon: HvpIcons.glove, label: 'Coach ${session.coachName}'),
            ],
            if (session.isExam) ...<Widget>[
              const SizedBox(height: 8),
              const StatusChip(
                  label: 'Kiểm tra',
                  tone: ChipTone.warning,
                  icon: HvpIcons.exam),
            ],
            if (cancellable)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: context.hvp.red,
                        minimumSize:
                            const Size(HvpLayout.minTap, HvpLayout.minTap)),
                    onPressed: () => _cancel(context, ref),
                    icon: const Icon(HvpIcons.xCircle, size: 18),
                    label: const Text('Huỷ buổi')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final done = await showHvpSheet<bool>(context,
        title: 'Huỷ buổi tập',
        builder: (_) => _CancelSheet(sessionId: session.id));
    if (done == true) {
      ref.invalidate(classSessionsProvider(classId));
      if (context.mounted) HvpToast.success(context, 'Đã huỷ buổi.');
    }
  }
}

String _statusLabel(String status) => switch (status) {
      'SCHEDULED' => 'Sắp diễn ra',
      'IN_PROGRESS' => 'Đang diễn ra',
      'COMPLETED' => 'Đã xong',
      'CANCELLED' => 'Đã huỷ',
      _ => status,
    };

ChipTone _statusTone(String status) => switch (status) {
      'SCHEDULED' => ChipTone.info,
      'IN_PROGRESS' => ChipTone.warning,
      'COMPLETED' => ChipTone.success,
      'CANCELLED' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

IconData _statusIcon(String status) => switch (status) {
      'SCHEDULED' => HvpIcons.upcoming,
      'IN_PROGRESS' => HvpIcons.play,
      'COMPLETED' => HvpIcons.checkCircle,
      'CANCELLED' => HvpIcons.block,
      _ => HvpIcons.info,
    };

class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(classSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invalid = validateCancelReason(_reason.text);
    setState(() => _error = invalid);
    if (invalid != null) return;
    final ok = await ref.read(classSubmitProvider.notifier).run(() => ref
        .read(classRepositoryProvider)
        .cancelSession(widget.sessionId, _reason.text));
    if (mounted && ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(classSubmitProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Học viên của buổi sẽ nhận thông báo kèm lý do.',
                style: context.txt.bodySmall),
            const SizedBox(height: 12),
            HvpTextField(
                label: 'Lý do huỷ',
                controller: _reason,
                maxLength: cancelReasonMax,
                maxLines: 2),
            if (_error != null)
              Text(_error!,
                  style:
                      context.txt.bodySmall.copyWith(color: context.hvp.red)),
            if (submit.error != null) ...<Widget>[
              const SizedBox(height: 8),
              InlineBanner(message: submit.error!)
            ],
            const SizedBox(height: 16),
            HvpButton.danger(
                label: 'Huỷ buổi',
                expand: true,
                loading: submit.submitting,
                onPressed: submit.submitting ? null : _submit),
          ]),
    );
  }
}
