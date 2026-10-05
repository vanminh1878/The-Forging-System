import 'package:flutter/material.dart';

import '../../core/design/hvp_layout.dart';
import 'account_panel.dart';

/// Student "Hồ sơ" tab: account card, theme switch and logout only.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: HvpLayout.tabPagePadding,
      children: const <Widget>[AccountPanel()],
    );
  }
}
