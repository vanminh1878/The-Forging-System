import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/form_focus.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_time_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/branch_input.dart';
import '../providers/branch_admin_providers.dart';
import 'branch_reason_sheet.dart';

/// BR-05: add a branch, or edit [branch]. The code is assigned by the server
/// (CN001, CN002...) and shown read-only; the position is picked on a map.
class BranchFormSheet extends ConsumerStatefulWidget {
  const BranchFormSheet({super.key, this.branch});

  final Branch? branch;

  @override
  ConsumerState<BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends ConsumerState<BranchFormSheet> {
  static const String _codePending = 'Tự động tạo khi lưu';

  final _formKey = GlobalKey<FormState>();
  late final _code =
      TextEditingController(text: widget.branch?.code ?? _codePending);
  late final _name = TextEditingController(text: widget.branch?.name);
  late final _address = TextEditingController(text: widget.branch?.address);
  late final _open = TextEditingController(text: _hours?.$1);
  late final _close = TextEditingController(text: _hours?.$2);
  late final _position = TextEditingController(text: _positionText());
  late final _radius = TextEditingController(
      text: (widget.branch?.geofenceRadiusM ?? 100).toString());
  final _nameFocus = FocusNode();
  final _openFocus = FocusNode();
  final _closeFocus = FocusNode();
  final _radiusFocus = FocusNode();

  late final (String, String)? _hours =
      BranchRules.splitHours(widget.branch?.openingHours);

  /// Old free-text opening hours that cannot be shown in the two pickers. They
  /// are kept as they are until the admin picks new times.
  late final String? _legacyHours =
      _hours == null && (widget.branch?.openingHours ?? '').trim().isNotEmpty
          ? widget.branch!.openingHours!.trim()
          : null;

  late double? _lat = widget.branch?.latitude;
  late double? _lng = widget.branch?.longitude;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(branchFormSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _code,
      _name,
      _address,
      _open,
      _close,
      _position,
      _radius
    ]) {
      c.dispose();
    }
    for (final f in <FocusNode>[
      _nameFocus,
      _openFocus,
      _closeFocus,
      _radiusFocus
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  String _positionText() {
    final lat = widget.branch?.latitude;
    final lng = widget.branch?.longitude;
    return lat == null || lng == null ? '' : _format(lat, lng);
  }

  static String _format(double lat, double lng) =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  Future<void> _pickPosition() async {
    final lat = _lat;
    final lng = _lng;
    final picked = await ref.read(branchMapPickerProvider)(
        context, lat == null || lng == null ? null : LatLng(lat, lng));
    if (picked == null || !mounted) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _position.text = _format(_lat!, _lng!);
    });
  }

  void _clearPosition() => setState(() {
        _lat = null;
        _lng = null;
        _position.clear();
      });

  /// "06:00 – 21:30"; the old free text when no new time was picked; else null.
  String? _openingHours() {
    final o = _open.text.trim();
    final c = _close.text.trim();
    if (o.isEmpty && c.isEmpty) return _legacyHours;
    return BranchRules.joinHours(o, c);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      focusFirstInvalid(<(FocusNode, String? Function())>[
        (_nameFocus, () => BranchRules.name(_name.text)),
        (_openFocus, () => BranchRules.openingTime(_open.text, _close.text)),
        (_closeFocus, () => BranchRules.closingTime(_open.text, _close.text)),
        (_radiusFocus, () => BranchRules.radius(_radius.text)),
      ]);
      return;
    }
    final input = BranchInput(
      name: _name.text,
      address: _address.text,
      openingHours: _openingHours(),
      latitude: _lat,
      longitude: _lng,
      geofenceRadiusM: int.parse(_radius.text.trim()),
    );
    final repo = ref.read(branchAdminRepositoryProvider);
    final editing = widget.branch;
    final ok = await ref.read(branchFormSubmitProvider.notifier).run(() async {
      editing == null
          ? await repo.create(input)
          : await repo.update(editing.id, input);
    });
    if (!mounted || !ok) return;
    ref.invalidate(adminBranchesProvider);
    HvpToast.success(
        context, editing == null ? 'Đã tạo chi nhánh' : 'Đã lưu thay đổi');
    Navigator.of(context).pop();
  }

  /// Extra: the on/off switch asks for a reason, then closes the form.
  Future<void> _toggleActive(Branch branch, bool isActive) async {
    final repo = ref.read(branchAdminRepositoryProvider);
    final done = await showReasonSheet(
      context,
      title: isActive ? 'Kích hoạt lại chi nhánh' : 'Ngừng hoạt động chi nhánh',
      confirmLabel: isActive ? 'Kích hoạt lại' : 'Ngừng hoạt động',
      required: true,
      submit: branchStatusSubmitProvider,
      onConfirm: (reason) =>
          repo.setActive(branch.id, isActive: isActive, reason: reason!),
    );
    if (!mounted || done != true) return;
    ref.invalidate(adminBranchesProvider);
    HvpToast.success(
        context,
        isActive
            ? 'Đã kích hoạt lại chi nhánh'
            : 'Đã ngừng hoạt động chi nhánh');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(branchFormSubmitProvider);
    const gap = SizedBox(height: 14);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HvpTextField(
              label: 'Tên chi nhánh',
              controller: _name,
              focusNode: _nameFocus,
              required: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  BranchRules.name(v) ?? submit.fieldErrors['name'],
            ),
            gap,
            HvpTextField(
              label: 'Mã chi nhánh',
              controller: _code,
              enabled: false,
              maxLength: 20,
              helper: 'Hệ thống tự tạo, không sửa được.',
            ),
            gap,
            HvpTextField(
              label: 'Địa chỉ',
              controller: _address,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: BranchRules.address,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: HvpTimeField(
                    label: 'Giờ mở cửa',
                    controller: _open,
                    focusNode: _openFocus,
                    textInputAction: TextInputAction.next,
                    validator: (v) => BranchRules.openingTime(v, _close.text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HvpTimeField(
                    label: 'Giờ đóng cửa',
                    controller: _close,
                    focusNode: _closeFocus,
                    textInputAction: TextInputAction.next,
                    validator: (v) => BranchRules.closingTime(_open.text, v),
                  ),
                ),
              ],
            ),
            if (_legacyHours != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Giờ đang lưu: $_legacyHours. Chọn giờ mở và đóng cửa để thay thế.',
                    style: context.txt.caption),
              ),
            gap,
            HvpTextField(
              label: 'Vị trí (vĩ độ, kinh độ)',
              hint: 'Chạm để chọn trên bản đồ',
              controller: _position,
              readOnly: true,
              suffixIcon: HvpIcons.mapPin,
              onTap: _pickPosition,
            ),
            if (_lat != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _clearPosition, child: const Text('Xóa vị trí')),
              ),
            gap,
            HvpTextField(
              label: 'Bán kính check-in (m)',
              controller: _radius,
              focusNode: _radiusFocus,
              required: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              validator: BranchRules.radius,
            ),
            if (submit.error != null) ...<Widget>[
              const SizedBox(height: 16),
              InlineBanner(message: submit.error!),
            ],
            const SizedBox(height: 24),
            HvpButton.primary(
                label: widget.branch == null ? 'Tạo chi nhánh' : 'Lưu thay đổi',
                expand: true,
                loading: submit.submitting,
                onPressed: submit.submitting ? null : _submit),
            if (widget.branch != null)
              // Material ancestor so the tile's ink shows above the sheet's decorated container.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.branch!.isActive,
                  activeThumbColor: context.hvp.gold,
                  title: Text('Đang hoạt động', style: context.txt.body),
                  onChanged: (v) => _toggleActive(widget.branch!, v),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
