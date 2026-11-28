import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/admin_armory_repository.dart';
import '../admin_armory_providers.dart';

class AdminArmoryRewardFormScreen extends ConsumerStatefulWidget {
  const AdminArmoryRewardFormScreen({super.key, this.reward});

  final AdminArmoryReward? reward;

  @override
  ConsumerState<AdminArmoryRewardFormScreen> createState() =>
      _AdminArmoryRewardFormScreenState();
}

class _AdminArmoryRewardFormScreenState
    extends ConsumerState<AdminArmoryRewardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _sku = TextEditingController(text: widget.reward?.sku ?? '');
  late final _name = TextEditingController(text: widget.reward?.name ?? '');
  late final _description =
      TextEditingController(text: widget.reward?.description ?? '');
  late final _imageUrl =
      TextEditingController(text: widget.reward?.imageUrl ?? '');
  late final _marksCost =
      TextEditingController(text: widget.reward?.marksCost.toString() ?? '');
  late final _stock =
      TextEditingController(text: widget.reward?.stock.toString() ?? '0');
  late final _limit = TextEditingController(
      text: widget.reward?.perMemberLimit?.toString() ?? '');
  late final _pickupDays =
      TextEditingController(text: widget.reward?.pickupDays?.toString() ?? '');
  final _reason = TextEditingController();
  String? _tierCode;
  String? _limitPeriod;
  late bool _isActive = widget.reward?.isActive ?? true;

  bool get _isEdit => widget.reward != null;

  @override
  void initState() {
    super.initState();
    _tierCode = widget.reward?.tierCode;
    _limitPeriod = widget.reward?.limitPeriod;
    Future<void>.microtask(
      () => ref
          .read((_isEdit
                  ? updateArmoryRewardSubmitProvider
                  : createArmoryRewardSubmitProvider)
              .notifier)
          .reset(),
    );
  }

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _marksCost.dispose();
    _stock.dispose();
    _limit.dispose();
    _pickupDays.dispose();
    _reason.dispose();
    super.dispose();
  }

  int? _integer(String value) => int.tryParse(value.trim());

  String? _positive(String? value, String label, {bool zeroAllowed = false}) {
    final number = _integer(value ?? '');
    if (number == null || number < (zeroAllowed ? 0 : 1)) {
      return '$label phải là số nguyên ${zeroAllowed ? 'không âm' : 'lớn hơn 0'}.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hasLimit = _limit.text.trim().isNotEmpty;
    if (hasLimit != (_limitPeriod != null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Giới hạn đổi cần có cả số lượng và chu kỳ.'),
      ));
      return;
    }
    final base = CreateArmoryRewardInput(
      sku: _sku.text,
      name: _name.text,
      marksCost: _integer(_marksCost.text)!,
      stock: _integer(_stock.text)!,
      description: _description.text.trim().isEmpty ? null : _description.text,
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text,
      tierCode: _tierCode,
      perMemberLimit: hasLimit ? _integer(_limit.text) : null,
      limitPeriod: _limitPeriod,
      minRankId: widget.reward?.minRankId,
      pickupDays:
          _pickupDays.text.trim().isEmpty ? null : _integer(_pickupDays.text),
      saleStartsAt: widget.reward?.saleStartsAt,
      saleEndsAt: widget.reward?.saleEndsAt,
      isActive: _isActive,
    );
    final repository = ref.read(adminArmoryRepositoryProvider);
    final success = _isEdit
        ? await ref.read(updateArmoryRewardSubmitProvider.notifier).run(
              () => repository.updateReward(
                widget.reward!.id,
                UpdateArmoryRewardInput(
                  sku: base.sku,
                  name: base.name,
                  marksCost: base.marksCost,
                  stock: base.stock,
                  description: base.description,
                  imageUrl: base.imageUrl,
                  tierCode: base.tierCode,
                  perMemberLimit: base.perMemberLimit,
                  limitPeriod: base.limitPeriod,
                  minRankId: base.minRankId,
                  pickupDays: base.pickupDays,
                  saleStartsAt: base.saleStartsAt,
                  saleEndsAt: base.saleEndsAt,
                  isActive: base.isActive,
                  reason: _reason.text,
                ),
              ),
            )
        : await ref.read(createArmoryRewardSubmitProvider.notifier).run(
              () => repository.createReward(base),
            );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Đã cập nhật quà.' : 'Đã tạo quà.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tiers = ref.watch(adminArmoryTiersProvider);
    final submit = ref.watch(_isEdit
        ? updateArmoryRewardSubmitProvider
        : createArmoryRewardSubmitProvider);
    return Scaffold(
      appBar: HvpAppBar(
          title: _isEdit ? 'Chi tiết quà' : 'Tạo quà Armory',
          titleIcon: HvpIcons.gift),
      body: AsyncBody<List<AdminArmoryTier>>(
        value: tiers,
        onRetry: () => ref.invalidate(adminArmoryTiersProvider),
        builder: (_, availableTiers) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  IconLabel(
                      icon: HvpIcons.gift,
                      iconSize: 22,
                      label: 'THÔNG TIN QUÀ',
                      style: context.txt.titleL),
                  const SizedBox(height: 16),
                  HvpTextField(
                    label: 'SKU',
                    controller: _sku,
                    readOnly: _isEdit,
                    maxLength: 80,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9._-]')),
                      TextInputFormatter.withFunction((oldValue, newValue) =>
                          newValue.copyWith(text: newValue.text.toUpperCase())),
                    ],
                    validator: (value) => RegExp(r'^[A-Z0-9][A-Z0-9._-]{1,79}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'SKU gồm 2–80 ký tự A-Z, số, ., _ hoặc -',
                  ),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Tên quà',
                      controller: _name,
                      maxLength: 150,
                      validator: (value) => (value?.trim().length ?? 0) >= 2
                          ? null
                          : 'Tên quà cần ít nhất 2 ký tự.'),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Mô tả',
                      controller: _description,
                      maxLines: 3,
                      maxLength: 2000),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _tierCode,
                    decoration: const InputDecoration(labelText: 'TIER QUÀ'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Không phân tier')),
                      ...availableTiers.map((tier) => DropdownMenuItem<String?>(
                          value: tier.code,
                          child: Text('${tier.name} (${tier.code})'))),
                    ],
                    onChanged: submit.submitting
                        ? null
                        : (value) => setState(() => _tierCode = value),
                  ),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Giá Marks',
                      controller: _marksCost,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) => _positive(value, 'Giá Marks')),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Tồn kho',
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) =>
                          _positive(value, 'Tồn kho', zeroAllowed: true)),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'URL ảnh',
                      controller: _imageUrl,
                      maxLength: 2000,
                      keyboardType: TextInputType.url),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Giới hạn đổi mỗi người',
                      controller: _limit,
                      hint: 'Để trống nếu không giới hạn',
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? null
                              : _positive(value, 'Giới hạn đổi')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _limitPeriod,
                    decoration:
                        const InputDecoration(labelText: 'CHU KỲ GIỚI HẠN'),
                    items: const <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                          value: null, child: Text('Không áp dụng')),
                      DropdownMenuItem<String?>(
                          value: 'MONTH', child: Text('Theo tháng')),
                      DropdownMenuItem<String?>(
                          value: 'YEAR', child: Text('Theo năm')),
                      DropdownMenuItem<String?>(
                          value: 'LIFETIME', child: Text('Trọn đời')),
                    ],
                    onChanged: submit.submitting
                        ? null
                        : (value) => setState(() => _limitPeriod = value),
                  ),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Hạn nhận quà (ngày)',
                      controller: _pickupDays,
                      hint: 'Để trống nếu không giới hạn',
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? null
                              : _positive(value, 'Hạn nhận quà')),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: submit.submitting
                        ? null
                        : (value) => setState(() => _isActive = value),
                    title: const Text('Đang bán'),
                  ),
                  if (_isEdit)
                    HvpTextField(
                        label: 'Lý do cập nhật',
                        controller: _reason,
                        maxLength: 500,
                        validator: (value) => (value?.trim().length ?? 0) >= 3
                            ? null
                            : 'Nhập lý do ít nhất 3 ký tự.'),
                  if (submit.error != null) ...<Widget>[
                    const SizedBox(height: 18),
                    InlineBanner(message: submit.error!)
                  ],
                  const SizedBox(height: 28),
                  HvpButton.primary(
                      label: _isEdit ? 'Lưu thay đổi' : 'Tạo quà',
                      expand: true,
                      loading: submit.submitting,
                      onPressed: submit.submitting ? null : _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
