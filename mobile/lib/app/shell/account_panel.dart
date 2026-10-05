import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/hvp_context.dart';
import '../../core/design/hvp_icons.dart';
import '../../core/widgets/hvp_avatar.dart';
import '../../core/widgets/hvp_bottom_sheet.dart';
import '../../core/widgets/hvp_button.dart';
import '../../core/widgets/hvp_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_chip.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import 'theme_mode_selector.dart';

/// Vietnamese name of an app role.
String roleLabel(AppRole role) {
  switch (role) {
    case AppRole.student:
      return 'Học viên';
    case AppRole.coach:
      return 'Huấn luyện viên';
    case AppRole.reception:
      return 'Lễ tân';
    case AppRole.admin:
      return 'Quản trị viên';
  }
}

/// Minimal account area: identity card, theme switch and logout.
/// Used by the student Hồ sơ tab and by the account sheet of the other roles.
class AccountPanel extends ConsumerWidget {
  const AccountPanel({super.key, this.inSheet = false});

  /// Adds the side padding that a sheet needs (a tab page gets it from its list).
  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final user = ref.watch(currentUserProvider);
    final contact = user == null ? null : (user.phone ?? user.email);
    return Padding(
      padding: EdgeInsets.fromLTRB(inSheet ? 20 : 0, 8, inSheet ? 20 : 0, inSheet ? 20 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (user != null)
            HvpCard(
              highlighted: true,
              semanticLabel: 'Tài khoản ${user.fullName}',
              child: Row(
                children: <Widget>[
                  HvpAvatar(url: user.avatarUrl, name: user.fullName, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(user.fullName, style: t.titleM, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (contact != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(contact, style: t.mono.copyWith(fontSize: 12)),
                        ],
                        const SizedBox(height: 8),
                        StatusChip(label: roleLabel(user.appRole), tone: ChipTone.gold, icon: HvpIcons.shieldCheck),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SectionHeader(title: 'Giao diện', padding: EdgeInsets.only(top: 20, bottom: 10)),
          const ThemeModeSelector(),
          const SizedBox(height: 24),
          HvpButton.danger(
            label: 'Đăng xuất',
            icon: HvpIcons.signOut,
            expand: true,
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Read before awaiting: the panel (and its ref) may be gone afterwards.
    final auth = ref.read(authControllerProvider.notifier);
    final confirmed = await showConfirmSheet(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (inSheet) Navigator.of(context).pop();
    await auth.logout();
  }
}
