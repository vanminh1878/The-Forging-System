import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';
import '../../domain/package_class_option.dart';
import '../providers/membership_providers.dart';
import 'package_class_picker.dart';
import 'package_tile.dart';

/// MEM-10: opens the "Chọn gói tập" picker.
Future<void> showRenewalSheet(BuildContext context) => showHvpSheet<void>(
      context,
      title: 'Chọn gói tập',
      builder: (_) => const RenewalSheet(),
    );

class RenewalSheet extends ConsumerStatefulWidget {
  const RenewalSheet({super.key});

  @override
  ConsumerState<RenewalSheet> createState() => _RenewalSheetState();
}

class _RenewalSheetState extends ConsumerState<RenewalSheet> {
  final _note = TextEditingController();
  String? _selectedId;
  PackageClassOption? _class;

  /// Step 2 (choose a class) is open; only for packages with classes.
  bool _classStep = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(renewalSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pick(PackageType p) => setState(() {
        if (p.id != _selectedId) _class = null;
        _selectedId = p.id;
      });

  Future<void> _submit(PackageType package) async {
    final cls = _class;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Gửi yêu cầu gia hạn?',
      message: <String>[
        '${package.name} · ${priceLabel(package.priceVnd)}',
        if (cls != null) 'Lớp: ${cls.name} · ${cls.branchName}',
      ].join('\n'),
      confirmLabel: 'Gửi yêu cầu',
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(renewalSubmitProvider.notifier).run(() async {
      try {
        await ref.read(membershipRepositoryProvider).requestRenewal(
            packageTypeId: package.id, classId: cls?.id, note: _note.text);
      } on ApiException catch (e) {
        // Server state moved on: a pending request exists / package left sale /
        // the class filled up or closed.
        if (e.code == 'RENEWAL_PENDING_EXISTS') {
          ref.invalidate(myMembershipProvider);
        } else if (e.code == 'PACKAGE_NOT_AVAILABLE') {
          _selectedId = null;
          _class = null;
          _classStep = false;
          ref.invalidate(packageTypesProvider);
        } else if (e.code == 'CLASS_FULL' || e.code == 'CLASS_INACTIVE') {
          _class = null;
          ref.invalidate(packageClassesProvider(package.id));
        }
        rethrow;
      }
    });
    if (!mounted || !ok) return;
    ref.invalidate(myMembershipProvider);
    ref.invalidate(myRenewalRequestsProvider);
    HvpToast.success(context, 'Đã gửi yêu cầu gia hạn tới lễ tân.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(renewalSubmitProvider);
    return AsyncBody<List<PackageType>>(
      value: ref.watch(packageTypesProvider),
      onRetry: () => ref.invalidate(packageTypesProvider),
      loading: const SizedBox(height: 240, child: ShimmerList(itemCount: 3)),
      builder: (context, packages) {
        if (packages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: EmptyState(
              icon: HvpIcons.ticket,
              title: 'Hiện chưa có gói nào đang bán',
            ),
          );
        }
        PackageType? selected;
        for (final p in packages) {
          if (p.id == _selectedId) selected = p;
        }
        final inClassStep =
            _classStep && selected != null && selected.hasClasses;
        final needsClass = selected != null && selected.hasClasses;
        final sendReady = selected != null && (!needsClass || _class != null);
        final sendButton = HvpButton.primary(
          label: 'Gửi yêu cầu gia hạn',
          expand: true,
          loading: submit.submitting,
          onPressed:
              !sendReady || submit.submitting ? null : () => _submit(selected!),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (inClassStep) ...<Widget>[
                Row(children: <Widget>[
                  Expanded(
                      child: Text(selected.name, style: context.txt.titleS)),
                  TextButton(
                    onPressed: submit.submitting
                        ? null
                        : () => setState(() => _classStep = false),
                    child: const Text('Đổi gói'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Chọn lớp', style: context.txt.label),
                const SizedBox(height: 8),
                PackageClassPicker(
                  packageTypeId: selected.id,
                  selectedId: _class?.id,
                  enabled: !submit.submitting,
                  onChanged: (c) => setState(() => _class = c),
                ),
              ] else
                for (final p in packages) ...<Widget>[
                  PackageTile(
                    package: p,
                    selected: p.id == _selectedId,
                    onTap: submit.submitting ? null : () => _pick(p),
                  ),
                  const SizedBox(height: 10),
                ],
              if (!needsClass || inClassStep) ...<Widget>[
                const SizedBox(height: 4),
                HvpTextField(
                  label: 'Ghi chú (không bắt buộc)',
                  controller: _note,
                  maxLength: 500,
                  maxLines: 2,
                ),
                if (submit.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  InlineBanner(message: submit.error!),
                ],
                const SizedBox(height: 16),
                sendButton,
              ] else ...<Widget>[
                const SizedBox(height: 16),
                HvpButton.primary(
                  label: 'Tiếp tục',
                  expand: true,
                  onPressed: () => setState(() => _classStep = true),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
