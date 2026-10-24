import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';

/// Body of the admin "Cấu hình" tab: a menu of settings screens.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        HvpCard(
          onTap: () => context.push(AdminPaths.branches),
          child: Row(
            children: <Widget>[
              Icon(HvpIcons.mapPin, color: c.gold),
              const SizedBox(width: 12),
              Expanded(child: Text('Chi nhánh', style: t.titleS)),
              Icon(HvpIcons.caretRight, color: c.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Quy tắc, hạng và nhật ký hệ thống: sắp ra mắt.',
            style: t.bodySmall),
      ],
    );
  }
}
