import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/branch_picker.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../../membership/domain/membership_models.dart';
import '../../../package_admin/presentation/providers/package_admin_providers.dart';
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
  late String? _branchId = widget.existing?.branchId;
  late String _type =
      widget.existing?.sessionTypeCode ?? sessionTypes.first.code;
  late String? _courseId = widget.existing?.courseId;
  late String? _coachId = widget.existing?.defaultCoachId;
  late String? _packageId = widget.existing?.packageTypeId;
  late final Set<int> _weekdays = <int>{...?widget.existing?.weekdays};
  late bool _active = widget.existing?.isActive ?? true;
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
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false) ||
        _branchId == null ||
        _weekdays.isEmpty) {
      return;
    }
    final draft = ClassDraft(
      branchId: _branchId!,
      name: _name.text,
      sessionTypeCode: _type,
      courseId: _courseId,
      defaultCoachId: _coachId,
      packageTypeId: _packageId,
      weekdays: _weekdays.toList()..sort(),
      startTime: _time.text.trim(),
      durationMinutes: int.parse(_duration.text.trim()),
      capacity: _capacity.text.trim().isEmpty
          ? null
          : int.parse(_capacity.text.trim()),
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
    final packages =
        ref.watch(adminPackagesProvider).valueOrNull ?? const <PackageType>[];
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
                      maxLength: 120,
                      validator: validateClassName),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'LOẠI'),
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
                    decoration: const InputDecoration(labelText: 'KHÓA'),
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
                    initialValue: packages.any((p) => p.id == _packageId)
                        ? _packageId
                        : null,
                    decoration: const InputDecoration(labelText: 'GÓI TẬP'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Không thuộc gói')),
                      for (final p in packages)
                        DropdownMenuItem<String?>(
                            value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() => _packageId = v),
                  ),
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue:
                        coaches.any((c) => c.id == _coachId) ? _coachId : null,
                    decoration: const InputDecoration(labelText: 'COACH'),
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
                  Text('NGÀY TRONG TUẦN', style: context.txt.label),
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
                  HvpTextField(
                      label: 'Giờ (HH:mm)',
                      controller: _time,
                      validator: validateStartTime),
                  gap,
                  HvpTextField(
                      label: 'Thời lượng (phút)',
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      validator: validateDuration),
                  gap,
                  HvpTextField(
                      label: 'Sĩ số (trống = không giới hạn)',
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      validator: validateCapacity),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Đang hoạt động', style: context.txt.body),
                      value: _active,
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
