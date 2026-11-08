import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../../reception_checkin/presentation/reception_providers.dart';
import '../class_providers.dart';

/// CLS-08: find a learner and enrol them in the class.
Future<void> showEnrolSheet(BuildContext context, String classId) =>
    showHvpSheet<void>(context,
        title: 'Thêm học viên vào lớp',
        builder: (_) => EnrolMemberSheet(classId: classId));

class EnrolMemberSheet extends ConsumerStatefulWidget {
  const EnrolMemberSheet({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<EnrolMemberSheet> createState() => _EnrolMemberSheetState();
}

class _EnrolMemberSheetState extends ConsumerState<EnrolMemberSheet> {
  Timer? _debounce;
  String _text = '';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(classSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _text = value.trim());
    });
  }

  Future<void> _enrol(MemberHit member) async {
    final ok = await ref.read(classSubmitProvider.notifier).run(() =>
        ref.read(classRepositoryProvider).enrol(widget.classId, member.id));
    if (!mounted || !ok) return;
    ref.invalidate(classDetailProvider(widget.classId));
    ref.invalidate(classPageProvider);
    HvpToast.success(context, 'Đã thêm vào lớp.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(classSubmitProvider);
    final results = ref.watch(memberSearchProvider(_text));
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HvpTextField(
                  label: 'Tìm học viên',
                  hint: 'Tên, số điện thoại hoặc mã học viên',
                  prefixIcon: HvpIcons.search,
                  onChanged: _changed),
              if (submit.error != null) ...<Widget>[
                const SizedBox(height: 8),
                InlineBanner(message: submit.error!)
              ],
              const SizedBox(height: 8),
              Flexible(
                child: AsyncBody<MemberSearchResult>(
                  value: results,
                  onRetry: () => ref.invalidate(memberSearchProvider(_text)),
                  builder: (_, r) => r.items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                              _text.isEmpty
                                  ? 'Chưa có học viên.'
                                  : 'Không tìm thấy học viên.',
                              style: context.txt.bodySmall))
                      : ListView(shrinkWrap: true, children: <Widget>[
                          for (final m in r.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.fullName, style: context.txt.bodyL),
                              subtitle: Text(
                                  '${m.memberCode}${m.phone == null ? '' : ' · ${m.phone}'}',
                                  style: context.txt.bodySmall),
                              trailing: HvpButton.secondary(
                                  label: 'Thêm',
                                  small: true,
                                  onPressed: submit.submitting
                                      ? null
                                      : () => _enrol(m)),
                            ),
                        ]),
                ),
              ),
            ]),
      ),
    );
  }
}
