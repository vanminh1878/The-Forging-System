import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_filter_chip.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/hvp_refresh_overlay.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/redemption_status_chip.dart';
import '../domain/staff_redemption.dart';
import 'staff_redemption_providers.dart';

class GiftHandoverTab extends ConsumerStatefulWidget {
  const GiftHandoverTab({super.key});

  @override
  ConsumerState<GiftHandoverTab> createState() => _GiftHandoverTabState();
}

class _GiftHandoverTabState extends ConsumerState<GiftHandoverTab> {
  String? _status = 'READY_PICKUP';
  String _query = '';
  int _page = 1;

  ({String? status, String query, int page}) get _filter =>
      (status: _status, query: _query, page: _page);

  Future<void> _run(
      Future<void> Function(StaffRedemptionRepository repository)
          action) async {
    final success = await ref.read(staffRedemptionActionProvider.notifier).run(
          () => action(ref.read(staffRedemptionRepositoryProvider)),
        );
    if (!mounted || !success) return;
    setState(() => _page = 1);
    ref.invalidate(
        staffRedemptionListProvider((status: _status, query: _query, page: 1)));
  }

  Future<void> _approve(StaffRedemption item) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Duyệt đơn đổi quà',
      message: 'Chuyển đơn ${item.redemptionCode} sang Sẵn sàng nhận?',
      confirmLabel: 'Duyệt đơn',
    );
    if (confirmed) await _run((repository) => repository.approve(item.id));
  }

  Future<void> _deliver(StaffRedemption item) async {
    final result = await showHvpSheet<({String? reason, String? evidenceUrl})>(
      context,
      title: 'Xác nhận giao quà',
      builder: (_) => _DeliverySheet(item: item),
    );
    if (result == null) return;
    await _run((repository) => repository.deliver(item.id,
        reason: result.reason, evidenceUrl: result.evidenceUrl));
  }

  Future<void> _reject(StaffRedemption item) async {
    final reason = await showHvpSheet<String>(
      context,
      title: 'Từ chối đơn',
      builder: (_) => const _RejectReasonSheet(),
    );
    if (reason != null) {
      await _run((repository) => repository.reject(item.id, reason: reason));
    }
  }

  void _selectStatus(String? value) => setState(() {
        _status = value;
        _page = 1;
      });

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(staffRedemptionListProvider(_filter));
    final action = ref.watch(staffRedemptionActionProvider);
    final refreshing = results.isRefreshing && results.hasValue;
    return Column(children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: HvpTextField(
          label: 'Tìm đơn / học viên',
          hint: 'Mã đơn, mã học viên hoặc họ tên',
          prefixIcon: HvpIcons.search,
          onSubmitted: (value) => setState(() {
            _query = value.trim();
            _page = 1;
          }),
        ),
      ),
      SizedBox(
        height: 64,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            _filterChip(null, 'Tất cả'),
            _filterChip('READY_PICKUP', 'Sẵn sàng nhận'),
            _filterChip('PENDING_PICKUP', 'Chờ duyệt'),
            _filterChip('DELIVERED', 'Đã giao'),
            _filterChip('REJECTED', 'Từ chối'),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: HvpRefreshButton(
            refreshing: refreshing,
            onPressed: () =>
                ref.invalidate(staffRedemptionListProvider(_filter)),
          ),
        ),
      ),
      if (action.error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InlineBanner(message: action.error!),
        ),
      Expanded(
        child: HvpRefreshOverlay(
          refreshing: refreshing,
          label: 'Đang tải đơn quà…',
          child: AsyncBody<StaffRedemptionPage>(
            value: results,
            onRetry: () => ref.invalidate(staffRedemptionListProvider(_filter)),
            builder: (_, page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(staffRedemptionListProvider(_filter));
                await ref.read(staffRedemptionListProvider(_filter).future);
              },
              child: page.items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: HvpIcons.gift,
                            title: 'Không có đơn cần xử lý',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: <Widget>[
                        Text(
                          '${page.total} đơn · Trang ${page.page}/${page.totalPages}',
                          style: context.txt.caption,
                        ),
                        const SizedBox(height: 8),
                        for (final item in page.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RedemptionCard(
                              item: item,
                              submitting: action.submitting,
                              onApprove: () => _approve(item),
                              onDeliver: () => _deliver(item),
                              onReject: () => _reject(item),
                            ),
                          ),
                        HvpPaginationBar(
                          page: page.page,
                          totalPages: page.totalPages,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _filterChip(String? value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: HvpFilterChip(
          label: label,
          icon: value == null ? HvpIcons.all : redemptionStatusIcon(value),
          selected: _status == value,
          onSelected: () => _selectStatus(value),
        ),
      );
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({
    required this.item,
    required this.submitting,
    required this.onApprove,
    required this.onDeliver,
    required this.onReject,
  });

  final StaffRedemption item;
  final bool submitting;
  final VoidCallback onApprove;
  final VoidCallback onDeliver;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => HvpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(
                    child: IconLabel(
                        icon: HvpIcons.gift,
                        iconSize: 18,
                        label: item.rewardName,
                        style: context.txt.titleS)),
                RedemptionStatusChip(status: item.status),
              ]),
              const SizedBox(height: 4),
              IconLabel(
                  icon: HvpIcons.user,
                  label: '${item.memberFullName} · ${item.memberCode}'),
              const SizedBox(height: 3),
              IconLabel(
                  icon: HvpIcons.coins,
                  label:
                      '${item.redemptionCode} · ${formatInt(item.marksCost)} Marks'),
              const SizedBox(height: 3),
              IconLabel(
                  icon: HvpIcons.storefront,
                  label:
                      '${item.pickupBranchName} · ${formatDateTime(item.requestedAt)}',
                  style: context.txt.caption),
              if (item.reason != null) ...<Widget>[
                const SizedBox(height: 3),
                IconLabel(
                    icon: HvpIcons.note,
                    label: item.reason!,
                    style: context.txt.caption),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                if (item.status == 'PENDING_PICKUP')
                  HvpButton.primary(
                      label: 'Duyệt',
                      icon: HvpIcons.check,
                      small: true,
                      onPressed: submitting ? null : onApprove),
                if (item.status == 'READY_PICKUP')
                  HvpButton.gold(
                      label: 'Giao quà',
                      icon: HvpIcons.handover,
                      small: true,
                      onPressed: submitting ? null : onDeliver),
                if (item.status == 'PENDING_PICKUP' ||
                    item.status == 'READY_PICKUP')
                  HvpButton.danger(
                      label: 'Từ chối',
                      icon: HvpIcons.block,
                      small: true,
                      onPressed: submitting ? null : onReject),
              ]),
            ]),
      );
}

class _DeliverySheet extends ConsumerStatefulWidget {
  const _DeliverySheet({required this.item});

  final StaffRedemption item;

  @override
  ConsumerState<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends ConsumerState<_DeliverySheet> {
  final _reason = TextEditingController();
  String? _evidenceUrl;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isNotEmpty && reason.length < 3) {
      setState(() => _error = 'Lý do cần ít nhất 3 ký tự hoặc để trống.');
      return;
    }
    Navigator.of(context).pop(
      (reason: reason.isEmpty ? null : reason, evidenceUrl: _evidenceUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Xác nhận đã giao ${widget.item.rewardName} cho '
            '${widget.item.memberFullName}? Marks sẽ được trừ chính thức.',
            style: t.body,
          ),
          const SizedBox(height: 16),
          HvpTextField(
            label: 'Lý do / ghi chú',
            controller: _reason,
            hint: 'Không bắt buộc',
            maxLines: 2,
            maxLength: 500,
          ),
          const SizedBox(height: 16),
          ref.watch(deliveryPhotoFieldBuilderProvider)(
            context,
            (url) => setState(() => _evidenceUrl = url),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            InlineBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          HvpButton.gold(
            label: 'Xác nhận đã giao',
            icon: HvpIcons.handover,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Nhập lý do ít nhất 3 ký tự.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          HvpTextField(
            label: 'Lý do từ chối',
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!,
                style: context.txt.bodySmall.copyWith(color: context.hvp.red)),
          ],
          const SizedBox(height: 20),
          HvpButton.danger(
              label: 'Xác nhận từ chối',
              icon: HvpIcons.block,
              expand: true,
              onPressed: _submit),
        ]),
      );
}
