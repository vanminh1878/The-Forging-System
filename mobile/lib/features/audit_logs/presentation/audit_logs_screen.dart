import 'dart:convert';

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
              HvpTextField(
                  label: 'Loại đối tượng',
                  controller: entityType,
                  hint: 'VD: CHALLENGE'),
              HvpTextField(label: 'Mã đối tượng', controller: entityId),
              const SizedBox(height: 8),
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
          title: Text(item.action, style: context.txt.titleS),
          subtitle: Text(
              '${item.entityType} · ${item.entityId}\n${item.actorName ?? item.actorType} · ${formatDateTime(item.createdAt)}',
              style: context.txt.bodySmall),
          children: <Widget>[
            if (item.reason != null)
              _Detail(label: 'Lý do', value: item.reason!),
            if (item.beforeData != null)
              _Detail(label: 'Trước', value: _json(item.beforeData)),
            if (item.afterData != null)
              _Detail(label: 'Sau', value: _json(item.afterData)),
          ],
        ),
      );

  String _json(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(), style: context.txt.label),
              const SizedBox(height: 2),
              SelectableText(value, style: context.txt.bodySmall),
            ]),
      );
}
