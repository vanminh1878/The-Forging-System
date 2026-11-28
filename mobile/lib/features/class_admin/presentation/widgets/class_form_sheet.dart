import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/branch_picker.dart';
import '../../../../core/widgets/form_focus.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_field_decoration.dart';
import '../../../../core/widgets/hvp_limit_field.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_time_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';

/// CLS-07: create a class, or edit [existing] (only changed fields are sent).
Future<void> showClassForm(BuildContext context, {ClassSummary? existing}) =>
    showHvpSheet<void>(context,
        title: existing == null ? 'Tạo lớp / session' : 'Sửa lớp',
        builder: (_) => ClassFormSheet(existing: existing));

class ClassFormSheet extends ConsumerStatefulWidget {
  const ClassFormSheet({super.key, this.existing});

  final ClassSummary? existing;

  @override
  ConsumerState<ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends ConsumerState<ClassFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _time =
      TextEditingController(text: widget.existing?.startTime ?? '18:00');
  late final _duration =
      TextEditingController(text: '${widget.existing?.durationMinutes ?? 60}');
  late final _capacity =
      TextEditingController(text: widget.existing?.capacity?.toString() ?? '');
  final _nameFocus = FocusNode();
  final _timeFocus = FocusNode();
  final _durationFocus = FocusNode();
  final _capacityFocus = FocusNode();
  late String? _branchId = widget.existing?.branchId;
  late String _type =
      widget.existing?.sessionTypeCode ?? sessionTypes.first.code;
  late String? _courseId = widget.existing?.courseId;
  late String? _coachId = widget.existing?.defaultCoachId;
  late final Set<int> _weekdays = <int>{...?widget.existing?.weekdays};
  late bool _active = widget.existing?.isActive ?? true;

  /// "Không giới hạn sĩ số": a new class starts unlimited, as before.
  late bool _unlimited = widget.existing?.capacity == null;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(classSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _time,
      _duration,
      _capacity
    ]) {
      c.dispose();
    }
    for (final f in <FocusNode>[
      _nameFocus,
      _timeFocus,
      _durationFocus,
      _capacityFocus
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final valid = (_formKey.currentState?.validate() ?? false) &&
        _branchId != null &&
        _weekdays.isNotEmpty;
    if (!valid) {
      focusFirstInvalid(<(FocusNode, String? Function())>[
        (_nameFocus, () => validateClassName(_name.text)),
        (_timeFocus, () => validateStartTime(_time.text)),
        (_durationFocus, () => validateDuration(_duration.text)),
        if (!_unlimited)
          (_capacityFocus, () => validateCapacity(_capacity.text)),
      ]);
      return;
    }
    final draft = ClassDraft(
      branchId: _branchId!,
      name: _name.text,
      sessionTypeCode: _type,
      courseId: _courseId,
      defaultCoachId: _coachId,
      weekdays: _weekdays.toList()..sort(),
      startTime: _time.text.trim(),
      durationMinutes: int.parse(_duration.text.trim()),
      capacity: _unlimited ? null : int.parse(_capacity.text.trim()),
      isActive: _active,
    );
    final existing = widget.existing;
    final changes =
        existing == null ? null : draft.changesFrom(ClassDraft.of(existing));
    if (changes != null && changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final repo = ref.read(classRepositoryProvider);
    final ok = await ref.read(classSubmitProvider.notifier).run(() async {
      if (existing == null) {
        await repo.create(draft);
      } else {
        await repo.update(existing.id, changes!);
      }
    });
    if (!mounted || !ok) return;
    ref.invalidate(classPageProvider);
    ref.invalidate(classDetailProvider);
    HvpToast.success(
        context, existing == null ? 'Đã tạo lớp.' : 'Đã cập nhật lớp.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(classSubmitProvider);
    final coaches =
        ref.watch(classCoachesProvider).valueOrNull ?? const <ClassCoach>[];
    final courses = ref.watch(coursesProvider).valueOrNull ?? const [];
    final c = context.hvp;
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
                      label: 'Tên lớp',
                      controller: _name,
                      focusNode: _nameFocus,
                      required: true,
                      maxLength: classNameMax,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: validateClassName),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    dropdownColor: c.surfaceHigh,
                    style: context.txt.bodyL,
                    decoration: hvpFieldDecoration(context, label: 'Loại'),
                    items: [
                      for (final t in sessionTypes)
                        DropdownMenuItem(value: t.code, child: Text(t.label))
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue: courses.any((c) => c.id == _courseId)
                        ? _courseId
                        : null,
                    isExpanded: true,
                    dropdownColor: c.surfaceHigh,
                    style: context.txt.bodyL,
                    decoration: hvpFieldDecoration(context, label: 'Khóa học'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Không gắn khóa')),
                      for (final c in courses)
                        DropdownMenuItem<String?>(
                            value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _courseId = v),
                  ),
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue:
                        coaches.any((c) => c.id == _coachId) ? _coachId : null,
                    isExpanded: true,
                    dropdownColor: c.surfaceHigh,
                    style: context.txt.bodyL,
                    decoration: hvpFieldDecoration(context, label: 'Coach'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Chưa có coach')),
                      for (final c in coaches)
                        DropdownMenuItem<String?>(
                            value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _coachId = v),
                  ),
                  gap,
                  BranchPicker(
                      selectedId: _branchId,
                      onChanged: (b) => setState(() => _branchId = b?.id)),
                  if (_submitted && _branchId == null)
                    _error(context, 'Vui lòng chọn chi nhánh.'),
                  gap,
                  Text('Ngày trong tuần *', style: context.txt.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: <Widget>[
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(weekdaysLabel(<int>[d])),
                        selected: _weekdays.contains(d),
                        onSelected: (on) => setState(
                            () => on ? _weekdays.add(d) : _weekdays.remove(d)),
                      ),
                  ]),
                  if (_submitted && _weekdays.isEmpty)
                    _error(context, 'Chọn ít nhất một ngày.'),
                  gap,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: HvpTimeField(
                            label: 'Giờ bắt đầu',
                            controller: _time,
                            focusNode: _timeFocus,
                            required: true,
                            textInputAction: TextInputAction.next,
                            validator: validateStartTime),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HvpTextField(
                            label: 'Thời lượng (phút)',
                            controller: _duration,
                            focusNode: _durationFocus,
                            required: true,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: validateDuration),
                      ),
                    ],
                  ),
                  gap,
                  HvpLimitField(
                      label: 'Sĩ số tối đa',
                      unlimitedLabel: 'Không giới hạn sĩ số',
                      controller: _capacity,
                      focusNode: _capacityFocus,
                      unlimited: _unlimited,
                      onUnlimitedChanged: (v) => setState(() => _unlimited = v),
                      validator: validateCapacity),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Đang hoạt động', style: context.txt.body),
                      value: _active,
                      activeThumbColor: c.gold,
                      onChanged: (v) => setState(() => _active = v)),
                  if (submit.error != null)
                    InlineBanner(message: submit.error!),
                  const SizedBox(height: 16),
                  HvpButton.primary(
                      label: widget.existing == null ? 'Tạo lớp' : 'Lưu',
                      expand: true,
                      loading: submit.submitting,
                      onPressed: submit.submitting ? null : _submit),
                ]),
          ),
        ));
  }

  Widget _error(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text,
          style: context.txt.bodySmall.copyWith(color: context.hvp.red)));
}
