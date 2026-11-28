import 'package:flutter/material.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_sub_nav.dart';
import 'members_tab.dart';
import 'renewal_requests_view.dart';

/// Reception tab "Gói tập": the renewal inbox and the learner list.
class ReceptionMembershipsTab extends StatelessWidget {
  const ReceptionMembershipsTab({super.key});

  @override
  Widget build(BuildContext context) => const HvpSubTabs(
        items: <HvpSubNavItem>[
          HvpSubNavItem(label: 'Yêu cầu', icon: HvpIcons.inbox),
          HvpSubNavItem(label: 'Học viên', icon: HvpIcons.users),
        ],
        children: <Widget>[
          RenewalRequestsView(),
          MembersTab(),
        ],
      );
}
