import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/class_rules.dart';
import '../class_providers.dart';

/// CLS-09: exam session of a class on a chosen day.
Future<void> showExamSheet(BuildContext context,
        {required String classId, required String className}) =>
    showHvpSheet<void>(context,
        title: 'Buổi kiểm tra',
        builder: (_) =>
            ExamSessionSheet(classId: classId, className: className));

class ExamSessionSheet extends ConsumerStatefulWidget {
  const ExamSessionSheet(
      {super.key, required this.classId, required this.className});

  final String classId;
  final String className;

  @override
  ConsumerState<ExamSessionSheet> createState() => _ExamSessionSheetState();
}

class _ExamSessionSheetState extends ConsumerState<ExamSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  late final _class = TextEditingController(text: widget.className);
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(classSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _class.dispose();
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
    // Picking a day clears the "choose a day" error right away.
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(classSubmitProvider.notifier).run(() => ref
        .read(classRepositoryProvider)
        .createExamSession(widget.classId, toIsoDate(_day!),
            title: _title.text));
    if (!mounted || !ok) return;
    ref.invalidate(classSessionsProvider(widget.classId));
    HvpToast.success(context, 'Đã tạo buổi kiểm tra.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(classSubmitProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HvpTextField(label: 'Lớp', controller: _class, enabled: false),
              const SizedBox(height: 14),
              HvpTextField(
                  label: 'Ngày',
                  controller: _date,
                  required: true,
                  readOnly: true,
                  suffixIcon: HvpIcons.calendar,
                  onTap: _pickDay,
                  helper: 'Giờ và độ dài theo lịch của lớp.',
                  validator: (_) =>
                      _day == null ? 'Vui lòng chọn ngày.' : null),
              const SizedBox(height: 14),
              HvpTextField(
                  label: 'Tên buổi kiểm tra',
                  controller: _title,
                  maxLength: sessionTitleMax,
                  textCapitalization: TextCapitalization.sentences,
                  validator: validateExamTitle),
              if (submit.error != null) InlineBanner(message: submit.error!),
              const SizedBox(height: 16),
              HvpButton.primary(
                  label: 'Tạo buổi kiểm tra',
                  icon: HvpIcons.calendarCheck,
                  expand: true,
                  loading: submit.submitting,
                  onPressed: submit.submitting ? null : _submit),
            ]),
      ),
    );
  }
}
