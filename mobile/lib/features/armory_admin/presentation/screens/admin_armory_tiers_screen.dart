import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/admin_armory_repository.dart';
import '../admin_armory_providers.dart';

/// Creates an Armory tier. Tier lists, details and editing are separate work.
class AdminArmoryTiersScreen extends ConsumerStatefulWidget {
  const AdminArmoryTiersScreen({super.key, this.tier});

  final AdminArmoryTier? tier;

  @override
  ConsumerState<AdminArmoryTiersScreen> createState() =>
      _AdminArmoryTiersScreenState();
}

class _AdminArmoryTiersScreenState
    extends ConsumerState<AdminArmoryTiersScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.tier?.code ?? '');
  late final _name = TextEditingController(text: widget.tier?.name ?? '');
  late final _minMarks =
      TextEditingController(text: widget.tier?.minMarks.toString() ?? '');
  late final _maxMarks =
      TextEditingController(text: widget.tier?.maxMarks?.toString() ?? '');
  late final _sortOrder =
      TextEditingController(text: widget.tier?.sortOrder.toString() ?? '0');
  final _reason = TextEditingController();

  bool get _isEdit => widget.tier != null;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read((_isEdit
                  ? updateArmoryTierSubmitProvider
                  : createArmoryTierSubmitProvider)
              .notifier)
          .reset(),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _minMarks.dispose();
    _maxMarks.dispose();
    _sortOrder.dispose();
    _reason.dispose();
    super.dispose();
  }

  int? _integer(String value) => int.tryParse(value.trim());

  String? _nonNegative(
    String? value, {
    required String label,
    int max = 2147483647,
  }) {
    final number = _integer(value ?? '');
    if (number == null || number < 0 || number > max) {
      return '$label phải là số nguyên từ 0 đến $max.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minMarks = _integer(_minMarks.text)!;
    final maxMarks =
        _maxMarks.text.trim().isEmpty ? null : _integer(_maxMarks.text);
    if (maxMarks != null && maxMarks < minMarks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marks tối đa phải lớn hơn hoặc bằng Marks tối thiểu.'),
        ),
      );
      return;
    }
    final repository = ref.read(adminArmoryRepositoryProvider);
    final success = _isEdit
        ? await ref.read(updateArmoryTierSubmitProvider.notifier).run(
              () => repository.updateTier(
                widget.tier!.code,
                UpdateArmoryTierInput(
                  name: _name.text,
                  minMarks: minMarks,
                  maxMarks: maxMarks,
                  sortOrder: _integer(_sortOrder.text)!,
                  reason: _reason.text,
                ),
              ),
            )
        : await ref.read(createArmoryTierSubmitProvider.notifier).run(
              () => repository.createTier(CreateArmoryTierInput(
                code: _code.text,
                name: _name.text,
                minMarks: minMarks,
                maxMarks: maxMarks,
                sortOrder: _integer(_sortOrder.text)!,
              )),
            );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(_isEdit ? 'Đã cập nhật tier quà.' : 'Đã tạo tier quà.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(_isEdit
        ? updateArmoryTierSubmitProvider
        : createArmoryTierSubmitProvider);
    return Scaffold(
      appBar: HvpAppBar(
          title: _isEdit ? 'Chi tiết tier' : 'Tạo tier Armory',
          titleIcon: HvpIcons.tag),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                IconLabel(
                    icon: HvpIcons.tag,
                    iconSize: 22,
                    label: 'THÔNG TIN TIER',
                    style: context.txt.titleL),
                const SizedBox(height: 6),
                Text(
                  'Tier dùng để phân loại quà theo số Marks tích lũy.',
                  style: context.txt.bodySmall,
                ),
                const SizedBox(height: 20),
                HvpTextField(
                  label: 'Mã tier',
                  controller: _code,
                  hint: 'Ví dụ: BRONZE',
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  readOnly: _isEdit,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          newValue.copyWith(text: newValue.text.toUpperCase()),
                    ),
                  ],
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (!RegExp(r'^[A-Z0-9_]{2,50}$').hasMatch(code)) {
                      return 'Dùng 2–50 ký tự: A-Z, 0-9 hoặc gạch dưới.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                HvpTextField(
                  label: 'Tên tier',
                  controller: _name,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    return name.length >= 2
                        ? null
                        : 'Tên tier cần ít nhất 2 ký tự.';
                  },
                ),
                const SizedBox(height: 16),
                HvpTextField(
                  label: 'Marks tối thiểu',
                  controller: _minMarks,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      _nonNegative(value, label: 'Marks tối thiểu'),
                ),
                const SizedBox(height: 16),
                HvpTextField(
                  label: 'Marks tối đa',
                  controller: _maxMarks,
                  hint: 'Để trống nếu là tier cao nhất',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : _nonNegative(value, label: 'Marks tối đa'),
                ),
                const SizedBox(height: 16),
                HvpTextField(
                  label: 'Thứ tự hiển thị',
                  controller: _sortOrder,
                  helper: 'Số nhỏ hiển thị trước.',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      _nonNegative(value, label: 'Thứ tự', max: 32767),
                ),
                if (_isEdit) ...<Widget>[
                  const SizedBox(height: 16),
                  HvpTextField(
                    label: 'Lý do cập nhật',
                    controller: _reason,
                    maxLength: 500,
                    textInputAction: TextInputAction.done,
                    validator: (value) => (value?.trim().length ?? 0) >= 3
                        ? null
                        : 'Nhập lý do ít nhất 3 ký tự.',
                  ),
                ],
                if (submit.error != null) ...<Widget>[
                  const SizedBox(height: 18),
                  InlineBanner(message: submit.error!),
                ],
                const SizedBox(height: 28),
                HvpButton.primary(
                  label: _isEdit ? 'Lưu thay đổi' : 'Tạo tier',
                  icon: _isEdit ? HvpIcons.check : HvpIcons.newTier,
                  expand: true,
                  loading: submit.submitting,
                  onPressed: submit.submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
