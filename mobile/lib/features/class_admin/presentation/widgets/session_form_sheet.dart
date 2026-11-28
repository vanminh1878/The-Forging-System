import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/branch_picker.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_field_decoration.dart';
import '../../../../core/widgets/hvp_limit_field.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_time_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';

/// CLS-09: one-off or Academy session (`POST /sessions`).
Future<void> showSessionForm(BuildContext context) =>
    showHvpSheet<void>(context,
        title: 'Tạo buổi', builder: (_) => const SessionFormSheet());

class SessionFormSheet extends ConsumerStatefulWidget {
  const SessionFormSheet({super.key});

  @override
  ConsumerState<SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends ConsumerState<SessionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController(text: '18:00');
  final _duration = TextEditingController(text: '60');
  final _capacity = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'ACADEMY';
  String? _branchId;
  String? _coachId;
  DateTime? _day;
  bool _exam = false;
  bool _unlimited = true;
  bool _submitted = false;
  String? _pastError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(classSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _title,
      _date,
      _time,
      _duration,
      _capacity,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = toVietnamTime(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _date.text = formatCalendarDate(toIsoDate(picked));
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _pastError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false) ||
        _branchId == null ||
        _day == null) {
      return;
    }
    final startsAt = vietnamInstant(_day!, _time.text.trim());
    if (!startsAt.isAfter(DateTime.now())) {
      setState(() => _pastError = 'Không thể tạo buổi trong quá khứ.');
      return;
    }
    final draft = SessionDraft(
      sessionTypeCode: _type,
      branchId: _branchId!,
      startsAt: startsAt,
      durationMinutes: int.parse(_duration.text.trim()),
      title: _title.text,
      isExam: _exam,
      coachId: _coachId,
      capacity: _unlimited ? null : int.parse(_capacity.text.trim()),
      notes: _notes.text,
    );
    final ok = await ref
        .read(classSubmitProvider.notifier)
        .run(() => ref.read(classRepositoryProvider).createSession(draft));
    if (!mounted || !ok) return;
    HvpToast.success(context, 'Đã tạo buổi.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(classSubmitProvider);
    final coaches =
        ref.watch(classCoachesProvider).valueOrNull ?? const <ClassCoach>[];
    const gap = SizedBox(height: 14);
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HvpTextField(
                    label: 'Tiêu đề',
                    controller: _title,
                    required: true,
                    maxLength: sessionTitleMax,
                    textCapitalization: TextCapitalization.sentences,
                    validator: validateSessionTitle),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  dropdownColor: context.hvp.surfaceHigh,
                  style: context.txt.bodyL,
                  decoration: hvpFieldDecoration(context, label: 'Loại'),
                  items: [
                    for (final t in sessionTypes)
                      DropdownMenuItem(value: t.code, child: Text(t.label))
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                gap,
                BranchPicker(
                    selectedId: _branchId,
                    onChanged: (b) => setState(() => _branchId = b?.id)),
                if (_submitted && _branchId == null)
                  _error(context, 'Vui lòng chọn chi nhánh.'),
                gap,
                DropdownButtonFormField<String?>(
                  initialValue:
                      coaches.any((c) => c.id == _coachId) ? _coachId : null,
                  isExpanded: true,
                  dropdownColor: context.hvp.surfaceHigh,
                  style: context.txt.bodyL,
                  decoration: hvpFieldDecoration(context, label: 'Coach'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Người tạo buổi')),
                    for (final c in coaches)
                      DropdownMenuItem<String?>(
                          value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _coachId = v),
                ),
                gap,
                HvpTextField(
                    label: 'Ngày',
                    controller: _date,
                    required: true,
                    readOnly: true,
                    suffixIcon: HvpIcons.calendar,
                    onTap: _pickDay),
                if (_submitted && _day == null)
                  _error(context, 'Vui lòng chọn ngày.'),
                gap,
                HvpTimeField(
                    label: 'Giờ bắt đầu',
                    controller: _time,
                    required: true,
                    validator: validateStartTime),
                gap,
                HvpTextField(
                    label: 'Thời lượng (phút)',
                    controller: _duration,
                    required: true,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: validateSessionDuration),
                gap,
                HvpLimitField(
                    label: 'Sĩ số tối đa',
                    unlimitedLabel: 'Không giới hạn sĩ số',
                    controller: _capacity,
                    unlimited: _unlimited,
                    onUnlimitedChanged: (v) => setState(() => _unlimited = v),
                    validator: validateCapacity),
                gap,
                HvpTextField(
                    label: 'Ghi chú',
                    controller: _notes,
                    maxLength: sessionNotesMax,
                    maxLines: 2,
                    validator: validateSessionNotes),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Buổi kiểm tra', style: context.txt.body),
                    value: _exam,
                    onChanged: (v) => setState(() => _exam = v)),
                if (_pastError != null) _error(context, _pastError!),
                if (submit.error != null) InlineBanner(message: submit.error!),
                const SizedBox(height: 16),
                HvpButton.primary(
                    label: 'Tạo buổi',
                    expand: true,
                    loading: submit.submitting,
                    onPressed: submit.submitting ? null : _submit),
              ]),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text,
          style: context.txt.bodySmall.copyWith(color: context.hvp.red)));
}
