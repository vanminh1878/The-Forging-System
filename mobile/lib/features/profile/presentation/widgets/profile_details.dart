import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../fighter_record/presentation/providers/fighter_record_providers.dart';
import '../../domain/profile_models.dart';
import '../providers/profile_providers.dart';
import 'profile_edit_form.dart';

/// AUTH-12: personal info of the student Hồ sơ tab.
class ProfileDetails extends ConsumerStatefulWidget {
  const ProfileDetails({super.key});

  @override
  ConsumerState<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends ConsumerState<ProfileDetails> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    // The rank name is not in the profile response: reuse the fighter record.
    final rank =
        ref.watch(rankProgressProvider).valueOrNull?.current.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
                child: SectionHeader(
                    title: 'Thông tin cá nhân',
                    icon: HvpIcons.profileCard,
                    padding: EdgeInsets.only(top: 20, bottom: 10))),
            if (profile.hasValue && !_editing)
              IconButton(
                tooltip: 'Chỉnh sửa hồ sơ',
                icon: Icon(HvpIcons.pencil, color: context.hvp.gold),
                onPressed: () => setState(() => _editing = true),
              ),
          ],
        ),
        AsyncBody<MemberProfile>(
          value: profile,
          onRetry: () => ref.invalidate(profileProvider),
          loading: const SizedBox(
              height: 160, child: Center(child: CircularProgressIndicator())),
          builder: (_, p) => HvpCard(
            child: Column(
              children: <Widget>[
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ProfileEditForm(
                        profile: p,
                        onDone: () => setState(() => _editing = false)),
                  )
                else ...<Widget>[
                  _InfoRow(
                      icon: HvpIcons.user,
                      label: 'Họ và tên',
                      value: p.fullName),
                  _InfoRow(
                      icon: HvpIcons.phone,
                      label: 'Số điện thoại',
                      value: p.phone),
                  _InfoRow(icon: HvpIcons.mail, label: 'Email', value: p.email),
                ],
                _InfoRow(
                    icon: HvpIcons.event,
                    label: 'Ngày tham gia',
                    value: p.joinedAt == null ? null : formatDate(p.joinedAt!)),
                _InfoRow(
                    icon: HvpIcons.medal, label: 'Hạng hiện tại', value: rank),
                _InfoRow(
                    icon: HvpIcons.shieldCheck,
                    label: 'Trạng thái tài khoản',
                    value: p.statusLabel),
                _InfoRow(
                    icon: HvpIcons.storefront,
                    label: 'Chi nhánh chính',
                    value: p.homeBranchName),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: context.hvp.gold),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: Text(label, style: t.bodySmall)),
          Expanded(
            flex: 6,
            child: Text(value == null || value!.isEmpty ? '—' : value!,
                style: t.body, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
