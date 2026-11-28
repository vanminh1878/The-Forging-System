import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_sub_nav.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../settings/presentation/admin_settings_group.dart';

/// Body of the admin "Cấu hình" tab: a menu of settings screens.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HvpSubTabs(
      items: <HvpSubNavItem>[
        for (final tab in _settingsTabs)
          HvpSubNavItem(label: tab.label, icon: tab.icon)
      ],
      children: <Widget>[
        _OverviewTab(onBranches: () => context.push(AdminPaths.branches)),
        for (final tab in _settingsTabs.skip(1)) _ConfigTab(tab: tab),
      ],
    );
  }
}

class _SettingsTab {
  const _SettingsTab(
      {required this.label,
      required this.title,
      required this.description,
      required this.icon});
  final String label;
  final String title;
  final String description;
  final IconData icon;
}

const List<_SettingsTab> _settingsTabs = <_SettingsTab>[
  _SettingsTab(
      label: 'Tổng quan',
      title: 'Tổng quan',
      description: 'Quản lý các danh mục và cấu hình chung của hệ thống.',
      icon: HvpIcons.overview),
  _SettingsTab(
      label: 'Điểm & hạng',
      title: 'Điểm và hạng',
      description: 'DP, Marks, giới hạn điểm và quy tắc lên hạng.',
      icon: HvpIcons.trophy),
  _SettingsTab(
      label: 'Chuỗi tập',
      title: 'Chuỗi tập',
      description: 'Mốc chuỗi tập, điều kiện duy trì và Streak Freeze.',
      icon: HvpIcons.fire),
  _SettingsTab(
      label: 'Thử thách',
      title: 'Thử thách',
      description: 'Giới hạn phần thưởng và lịch nhắc thử thách.',
      icon: HvpIcons.flag),
  _SettingsTab(
      label: 'Armory',
      title: 'Armory',
      description: 'Hạn nhận quà và ngưỡng cảnh báo tồn kho.',
      icon: HvpIcons.armory),
  _SettingsTab(
      label: 'Check-in',
      title: 'Check-in',
      description: 'Mã QR, khung thời gian và vị trí check-in.',
      icon: HvpIcons.scan),
  _SettingsTab(
      label: 'Khác',
      title: 'Khác',
      description: 'Gói tập, lớp học, check-in và bảo mật.',
      icon: HvpIcons.more),
];

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.onBranches});
  final VoidCallback onBranches;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const IconLabel(
              icon: HvpIcons.info,
              label:
                  'Chọn nhóm cấu hình ở các tab bên trên để thiết lập quy tắc vận hành.'),
          const SizedBox(height: 16),
          HvpCard(
            onTap: onBranches,
            child: Row(children: <Widget>[
              Icon(HvpIcons.mapPin, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text('Chi nhánh', style: context.txt.titleS),
                    const SizedBox(height: 2),
                    Text('Địa chỉ, lịch mở cửa và khu vực check-in.',
                        style: context.txt.bodySmall),
                  ])),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          ),
          const SizedBox(height: 12),
          HvpCard(
            onTap: () => context.push(AdminPaths.pointsAdjustment),
            child: Row(children: <Widget>[
              Icon(HvpIcons.coins, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text('Điều chỉnh DP / Marks', style: context.txt.titleS),
                    const SizedBox(height: 2),
                    Text(
                        'Tìm học viên, xem sổ điểm và thực hiện điều chỉnh thủ công.',
                        style: context.txt.bodySmall),
                  ])),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          ),
        ],
      );
}

class _ConfigTab extends StatelessWidget {
  const _ConfigTab({required this.tab});
  final _SettingsTab tab;

  @override
  Widget build(BuildContext context) {
    final group = switch (tab.label) {
      'Điểm & hạng' => 'POINTS',
      'Chuỗi tập' => 'STREAK',
      'Thử thách' => 'CHALLENGE',
      'Armory' => 'ARMORY',
      'Check-in' => 'CHECKIN',
      _ => 'CHECKIN',
    };
    if (tab.label == 'Điểm & hạng') {
      return Column(children: <Widget>[
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: HvpCard(onTap: () => context.push(AdminPaths.rankConfiguration), child: Row(children: <Widget>[Icon(HvpIcons.trophy, color: context.hvp.gold), const SizedBox(width: 12), Expanded(child: Text('Cấu hình hạng', style: context.txt.titleS)), Icon(HvpIcons.caretRight, color: context.hvp.textMuted)]))),
        const Expanded(child: AdminSettingsGroup(group: 'POINTS')),
      ]);
    }
    if (tab.label != 'Khác') return AdminSettingsGroup(group: group);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        IconLabel(icon: tab.icon, label: tab.description),
        const SizedBox(height: 18),
        HvpCard(
          child: Row(children: <Widget>[
            Icon(HvpIcons.info, color: context.hvp.info),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Các tham số của nhóm này sẽ được hiển thị và chỉnh sửa tại đây.',
                    style: context.txt.bodySmall)),
          ]),
        ),
        if (tab.label == 'Khác') ...<Widget>[
          const SizedBox(height: 12),
          HvpCard(
            onTap: () => context.push(AdminPaths.configHistory),
            child: Row(children: <Widget>[
              Icon(HvpIcons.history, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Lịch sử cấu hình', style: context.txt.titleS)),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted)
            ]),
          ),
          const SizedBox(height: 12),
          HvpCard(
            onTap: () => context.push(AdminPaths.auditLogs),
            child: Row(children: <Widget>[
              Icon(HvpIcons.audit, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Nhật ký Audit', style: context.txt.titleS),
                    const SizedBox(height: 2),
                    Text(
                        'Tra cứu lịch sử thay đổi của quản trị viên và hệ thống.',
                        style: context.txt.bodySmall),
                  ],
                ),
              ),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          ),
          const SizedBox(height: 12),
          HvpCard(
            onTap: () => context.push(AdminPaths.renewalRequests),
            child: Row(children: <Widget>[
              Icon(HvpIcons.ticket, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Yêu cầu gia hạn', style: context.txt.titleS),
                    const SizedBox(height: 2),
                    Text('Duyệt hoặc huỷ yêu cầu gia hạn của học viên.',
                        style: context.txt.bodySmall),
                  ],
                ),
              ),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          ),
        ],
        if (tab.label == 'Armory') ...<Widget>[
          const SizedBox(height: 12),
          HvpCard(
            onTap: () => context.push(AdminPaths.armory),
            child: Row(children: <Widget>[
              Icon(HvpIcons.armory, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Quản lý Armory', style: context.txt.titleS),
                    const SizedBox(height: 2),
                    Text('Tier, quà tặng và trạng thái bán.',
                        style: context.txt.bodySmall),
                  ],
                ),
              ),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          ),
        ],
      ],
    );
  }
}
