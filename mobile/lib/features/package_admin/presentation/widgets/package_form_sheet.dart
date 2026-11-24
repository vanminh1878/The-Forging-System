import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../membership/domain/membership_models.dart';
import '../../domain/package_models.dart';
import '../../domain/package_rules.dart';
import '../providers/package_admin_providers.dart';

/// PKG-01: create a package, or edit [existing] (only changed fields are sent).
Future<void> showPackageForm(BuildContext context, {PackageType? existing}) =>
    showHvpSheet<void>(context,
        title: existing == null ? 'Thêm gói tập' : 'Sửa gói tập',
        builder: (_) => PackageFormSheet(existing: existing));

class PackageFormSheet extends ConsumerStatefulWidget {
  const PackageFormSheet({super.key, this.existing});

  final PackageType? existing;

  @override
  ConsumerState<PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends ConsumerState<PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _days =
      TextEditingController(text: widget.existing?.durationDays?.toString());
  late final _sessions =
      TextEditingController(text: widget.existing?.totalSessions?.toString());
  late final _perWeek =
      TextEditingController(text: widget.existing?.sessionsPerWeek?.toString());
  late final _price =
      TextEditingController(text: widget.existing?.priceVnd?.toString());
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _sort =
      TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');
  late bool _trial = widget.existing?.isTrial ?? false;
  late bool _active = widget.existing?.isActive ?? true;

  /// Server message for a duplicate code, shown under the code field.
  String? _codeError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(packageSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _code,
      _name,
      _days,
      _sessions,
      _perWeek,
      _price,
      _description,
      _sort
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    _codeError = null;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = PackageDraft(
      code: _code.text,
      name: _name.text,
      durationDays: parseOptionalInt(_days.text),
      totalSessions: parseOptionalInt(_sessions.text),
      sessionsPerWeek: parseOptionalInt(_perWeek.text),
      isTrial: _trial,
      priceVnd: parseOptionalInt(_price.text),
      description: _description.text,
      isActive: _active,
      sortOrder: int.parse(_sort.text.trim()),
    );
    final existing = widget.existing;
    final changes =
        existing == null ? null : draft.changesFrom(PackageDraft.of(existing));
    if (changes != null && changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final repo = ref.read(packageAdminRepositoryProvider);
    final ok = await ref.read(packageSubmitProvider.notifier).run(() async {
      try {
        if (existing == null) {
          await repo.create(draft);
        } else {
          await repo.update(existing.id, changes!);
        }
      } on ApiException catch (e) {
        if (e.code == 'PACKAGE_CODE_EXISTS') _codeError = e.message;
        rethrow;
      }
    });
    if (!mounted) return;
    if (!ok) {
      if (_codeError != null) _formKey.currentState?.validate();
      return;
    }
    ref.invalidate(adminPackagesProvider);
    HvpToast.success(
        context, existing == null ? 'Đã tạo gói' : 'Đã cập nhật gói');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(packageSubmitProvider);
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
                label: 'Mã gói',
                controller: _code,
                maxLength: 40,
                validator: (v) => validatePackageCode(v) ?? _codeError,
                onChanged: (_) => _codeError = null,
              ),
              gap,
              HvpTextField(
                  label: 'Tên gói',
                  controller: _name,
                  maxLength: 120,
                  validator: validatePackageName),
              gap,
              HvpTextField(
                  label: 'Số ngày (trống = không giới hạn)',
                  controller: _days,
                  keyboardType: TextInputType.number,
                  validator: validateOptionalInt(1, 3650)),
              gap,
              HvpTextField(
                  label: 'Số buổi (trống = không giới hạn)',
                  controller: _sessions,
                  keyboardType: TextInputType.number,
                  validator: validateOptionalInt(1, 1000)),
              gap,
              HvpTextField(
                  label: 'Số buổi mỗi tuần (không bắt buộc)',
                  controller: _perWeek,
                  keyboardType: TextInputType.number,
                  validator: validateOptionalInt(1, 14)),
              gap,
              HvpTextField(
                  label: 'Giá (VNĐ, không bắt buộc)',
                  controller: _price,
                  keyboardType: TextInputType.number,
                  validator: validateOptionalInt(0, 1000000000)),
              gap,
              HvpTextField(
                  label: 'Mô tả (không bắt buộc)',
                  controller: _description,
                  maxLines: 3,
                  maxLength: 1000,
                  validator: validateDescription),
              gap,
              HvpTextField(
                  label: 'Thứ tự hiển thị',
                  controller: _sort,
                  keyboardType: TextInputType.number,
                  validator: validateSortOrder),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Gói trải nghiệm', style: context.txt.body),
                  value: _trial,
                  onChanged: (v) => setState(() => _trial = v)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Đang bán', style: context.txt.body),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v)),
              if (submit.error != null && _codeError == null)
                InlineBanner(message: submit.error!),
              const SizedBox(height: 16),
              HvpButton.primary(
                  label: widget.existing == null ? 'Tạo gói' : 'Lưu',
                  expand: true,
                  loading: submit.submitting,
                  onPressed: submit.submitting ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
