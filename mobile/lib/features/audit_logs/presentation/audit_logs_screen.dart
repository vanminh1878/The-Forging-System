import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../domain/audit_log.dart';
import 'audit_log_providers.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final _action = TextEditingController();
  final _entityType = TextEditingController();
  final _entityId = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  int _page = 1;

  AuditLogFilter get _filter => AuditLogFilter(
        action: _action.text.trim(),
        entityType: _entityType.text.trim(),
        entityId: _entityId.text.trim(),
        from: _from,
        to: _to,
        page: _page,
      );

  @override
  void dispose() {
    _action.dispose();
    _entityType.dispose();
    _entityId.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = DateTime(
            selected.year, selected.month, selected.day, 23, 59, 59, 999);
      }
      _page = 1;
    });
  }

  void _apply() => setState(() => _page = 1);

  void _clear() {
    setState(() {
      _action.clear();
      _entityType.clear();
      _entityId.clear();
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký Audit')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _Filters(
              action: _action,
              entityType: _entityType,
              entityId: _entityId,
              from: _from,
              to: _to,
              onFrom: () => _pickDate(true),
              onTo: () => _pickDate(false),
              onApply: _apply,
              onClear: _clear,
            ),
          ),
          Expanded(
            child: AsyncBody<AuditLogPage>(
              value: ref.watch(auditLogListProvider(filter)),
              onRetry: () => ref.invalidate(auditLogListProvider(filter)),
              builder: (_, data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(auditLogListProvider(filter));
                  await ref.read(auditLogListProvider(filter).future);
                },
                child: data.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const <Widget>[
                          SizedBox(
                              height: 300,
                              child: EmptyState(
                                  icon: HvpIcons.history,
                                  title: 'Chưa có nhật ký',
                                  message:
                                      'Không có thay đổi nào khớp với bộ lọc.'))
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: <Widget>[
                          Text(
                              '${data.total} bản ghi · Trang ${data.page}/${data.totalPages}',
                              style: context.txt.caption),
                          const SizedBox(height: 8),
                          for (final item in data.items)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AuditCard(item: item)),
                          HvpPaginationBar(
                              page: data.page,
                              totalPages: data.totalPages,
                              onPageChanged: (page) =>
                                  setState(() => _page = page)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters(
      {required this.action,
      required this.entityType,
      required this.entityId,
      required this.from,
      required this.to,
      required this.onFrom,
      required this.onTo,
      required this.onApply,
      required this.onClear});

  final TextEditingController action;
  final TextEditingController entityType;
  final TextEditingController entityId;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => HvpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('BỘ LỌC', style: context.txt.label),
              HvpTextField(
                  label: 'Hành động',
                  controller: action,
                  hint: 'VD: CHALLENGE_CREATED'),
              const SizedBox(height: 12),
              HvpTextField(
                  label: 'Loại đối tượng',
                  controller: entityType,
                  hint: 'VD: CHALLENGE'),
              const SizedBox(height: 12),
              HvpTextField(label: 'Mã đối tượng', controller: entityId),
              const SizedBox(height: 16),
              Row(children: <Widget>[
                Expanded(
                    child: _DateButton(
                        label: 'Từ ngày', value: from, onTap: onFrom)),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        _DateButton(label: 'Đến ngày', value: to, onTap: onTo)),
              ]),
              const SizedBox(height: 12),
              Row(children: <Widget>[
                Expanded(
                    child: HvpButton.primary(
                        label: 'Áp dụng', small: true, onPressed: onApply)),
                const SizedBox(width: 8),
                HvpButton.secondary(
                    label: 'Xóa lọc', small: true, onPressed: onClear),
              ]),
            ]),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(HvpIcons.calendar),
        label: Text(value == null ? label : formatDate(value!)),
      );
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.item});
  final AuditLogEntry item;

  @override
  Widget build(BuildContext context) => HvpCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Text(_actionLabel(item.action), style: context.txt.titleS),
          subtitle: Text(
              '${_entityLabel(item.entityType, item.entityId)}\n${item.actorName ?? item.actorType} · ${formatDateTime(item.createdAt)}',
              style: context.txt.bodySmall),
          children: <Widget>[
            if (item.reason != null)
              _Detail(label: 'Lý do', value: item.reason!),
            if (_Diff.canDisplay(item.beforeData, item.afterData))
              _Diff(
                  label: _entityLabel(item.entityType, item.entityId),
                  before: item.beforeData,
                  after: item.afterData),
          ],
        ),
      );

  String _actionLabel(String action) => switch (action) {
        'CONFIG_CHANGE' => 'Cập nhật cấu hình',
        'CONFIG_ROLLBACK' => 'Hoàn tác cấu hình',
        'RENEWAL_REQUESTED' => 'Yêu cầu gia hạn được tạo',
        'RENEWAL_APPROVED' => 'Lễ tân duyệt yêu cầu gia hạn',
        'DP_ADJUSTED' => 'Điều chỉnh DP / Marks',
        'DP_REVERSED' => 'Đảo giao dịch điểm',
        _ => 'Thay đổi hệ thống',
      };
  String _entityLabel(String type, String id) {
    if (type == 'SYSTEM_CONFIG') return _settingLabel(id);
    return switch (type) {
      'RENEWAL_REQUEST' => 'Yêu cầu gia hạn',
      'RANK_CONFIG' => 'Cấu hình hạng',
      _ => 'Bản ghi hệ thống'
    };
  }

  String _settingLabel(String key) => switch (key) {
        'checkin.code_ttl_seconds' => 'Thời hạn mã check-in',
        'points.dp_monthly_cap' => 'Hạn mức DP mỗi tháng',
        'points.marks_monthly_cap' => 'Hạn mức Marks mỗi tháng',
        _ => 'Cấu hình hệ thống',
      };
}

class _Diff extends StatelessWidget {
  const _Diff({required this.label, this.before, this.after});
  final String label;
  final Object? before;
  final Object? after;
  static bool canDisplay(Object? before, Object? after) =>
      before is! Map && before is! List && after is! Map && after is! List;
  String _value(Object? value) => value == null ? 'Chưa có' : '$value';
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('THAY ĐỔI', style: context.txt.label),
        const SizedBox(height: 4),
        Text(label, style: context.txt.bodySmall),
        const SizedBox(height: 6),
        Row(children: <Widget>[
          Expanded(child: _Detail(label: 'Trước', value: _value(before))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(HvpIcons.arrowRight)),
          Expanded(child: _Detail(label: 'Sau', value: _value(after)))
        ]),
      ]);
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(), style: context.txt.label),
              const SizedBox(height: 2),
              SelectableText(value, style: context.txt.bodySmall),
            ]),
      ));
}
