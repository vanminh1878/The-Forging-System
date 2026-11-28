import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/design/hvp_icons.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'branch_qr_screen.dart';

/// Opens the QR screen of the signed-in staff member's own branch (a receptionist belongs to one branch).
class BranchQrRoute extends ConsumerWidget {
  const BranchQrRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(authControllerProvider.select((s) => s.user?.branchId));
    if (branchId == null || branchId.isEmpty) {
      return Scaffold(
        appBar: const HvpAppBar(
            title: 'Mã QR quầy', titleIcon: HvpIcons.qrCode),
        body: EmptyState(
          icon: HvpIcons.scan,
          title: 'Chưa có chi nhánh',
          message: 'Tài khoản của bạn chưa được gán chi nhánh nên chưa hiển thị được mã QR.',
          actionLabel: 'Quay lại',
          onAction: () => context.canPop() ? context.pop() : context.go(ReceptionPaths.checkin),
        ),
      );
    }
    return BranchQrScreen(branchId: branchId);
  }
}
