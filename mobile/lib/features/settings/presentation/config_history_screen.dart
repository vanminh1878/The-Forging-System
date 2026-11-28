import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_filter_chip.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../audit_logs/domain/audit_log.dart';
import '../../audit_logs/presentation/audit_log_providers.dart';
import 'admin_settings_providers.dart';

class ConfigHistoryScreen extends ConsumerStatefulWidget {
  const ConfigHistoryScreen({super.key});
  @override
  ConsumerState<ConfigHistoryScreen> createState() =>
      _ConfigHistoryScreenState();
}

class _ConfigHistoryScreenState extends ConsumerState<ConfigHistoryScreen> {
  String _type = 'SYSTEM_CONFIG';
  int _page = 1;
  AuditLogFilter get _filter => AuditLogFilter(entityType: _type, page: _page);
  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return Scaffold(
        appBar: const HvpAppBar(
            title: 'Lịch sử cấu hình', titleIcon: HvpIcons.history),
        body: Column(children: <Widget>[
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: <Widget>[
                HvpFilterChip(
                    label: 'Settings',
                    icon: HvpIcons.gear,
                    selected: _type == 'SYSTEM_CONFIG',
                    onSelected: () => setState(() {
                          _type = 'SYSTEM_CONFIG';
                          _page = 1;
                        })),
                const SizedBox(width: 8),
                HvpFilterChip(
                    label: 'Rank',
                    icon: HvpIcons.medal,
                    selected: _type == 'RANK_CONFIG',
                    onSelected: () => setState(() {
                          _type = 'RANK_CONFIG';
                          _page = 1;
                        }))
              ])),
          Expanded(
              child: AsyncBody<AuditLogPage>(
                  value: ref.watch(auditLogListProvider(filter)),
                  onRetry: () => ref.invalidate(auditLogListProvider(filter)),
                  builder: (_, data) => data.items.isEmpty
                      ? const EmptyState(
                          icon: HvpIcons.history,
                          title: 'Chưa có lịch sử',
                          message: 'Chưa có thay đổi cấu hình.')
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                              for (final item in data.items)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _HistoryCard(
                                        item: item, canRollback: true))
                            ])))
        ]));
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item, required this.canRollback});
  final AuditLogEntry item;
  final bool canRollback;
  @override
  Widget build(BuildContext context, WidgetRef ref) => HvpCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
            IconLabel(
                icon: HvpIcons.gear,
                iconSize: 18,
                label: item.entityId,
                style: context.txt.titleS),
            IconLabel(
                icon: HvpIcons.user,
                label:
                    '${item.actorName ?? item.actorType} · ${item.createdAt.toLocal()}'),
            if (item.reason != null)
              IconLabel(icon: HvpIcons.note, label: item.reason!),
            if (canRollback)
              Align(
                  alignment: Alignment.centerRight,
                  child: HvpButton.secondary(
                      label: 'Hoàn tác',
                      icon: HvpIcons.history,
                      small: true,
                      onPressed: () => _rollback(context, ref)))
          ]));
  Future<void> _rollback(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Hoàn tác cấu hình'),
                content:
                    HvpTextField(label: 'Lý do hoàn tác', controller: reason),
                actions: <Widget>[
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('HUỶ')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, reason.text.trim()),
                      child: const Text('HOÀN TÁC'))
                ]));
    reason.dispose();
    if (value == null || value.length < 3) return;
    if (item.entityType == 'SYSTEM_CONFIG') {
      await ref
          .read(adminSettingsRepositoryProvider)
          .rollback(item.entityId, item.id, value);
    } else {
      await ref
          .read(rankConfigurationRepositoryProvider)
          .rollback(item.entityId, item.id, value);
    }
    ref.invalidate(
        auditLogListProvider(AuditLogFilter(entityType: item.entityType)));
  }
}
