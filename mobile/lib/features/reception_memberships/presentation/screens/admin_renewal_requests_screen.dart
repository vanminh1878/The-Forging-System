import 'package:flutter/material.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import 'renewal_requests_view.dart';

/// AMB-07: the renewal inbox for the admin, opened from Cấu hình > Khác.
class AdminRenewalRequestsScreen extends StatelessWidget {
  const AdminRenewalRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: HvpAppBar(title: 'Yêu cầu gia hạn', titleIcon: HvpIcons.inbox),
        body: RenewalRequestsView(approveLabel: 'ĐÃ THU PHÍ · DUYỆT'),
      );
}
