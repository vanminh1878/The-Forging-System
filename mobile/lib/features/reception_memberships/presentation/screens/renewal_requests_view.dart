import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_filter_chip.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../domain/renewal_models.dart';
import '../renewal_actions.dart';
import '../renewal_notifier.dart';
import '../widgets/renewal_card.dart';

/// Renewal request inbox: search, status filter, paging. Shared by the reception tab and the admin screen.
class RenewalRequestsView extends ConsumerStatefulWidget {
  const RenewalRequestsView(
      {super.key, this.approveLabel = 'ĐỒNG Ý · ĐÃ THU PHÍ'});

  final String approveLabel;

  @override
  ConsumerState<RenewalRequestsView> createState() =>
      _RenewalRequestsViewState();
}

class _RenewalRequestsViewState extends ConsumerState<RenewalRequestsView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(renewalFilterProvider.notifier).setQuery(value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(renewalFilterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: HvpTextField(
            label: 'Tìm yêu cầu',
            hint: 'Tên, số điện thoại hoặc mã học viên',
            prefixIcon: HvpIcons.search,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            onChanged: _typed,
            onSubmitted: (v) =>
                ref.read(renewalFilterProvider.notifier).setQuery(v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final entry in renewalStatusLabels.entries)
                HvpFilterChip(
                  label: entry.value,
                  icon: switch (entry.key) {
                    'COMPLETED' => HvpIcons.checkCircle,
                    'CANCELLED' => HvpIcons.xCircle,
                    _ => HvpIcons.hourglass,
                  },
                  selected: filter.status == entry.key,
                  onSelected: () => ref
                      .read(renewalFilterProvider.notifier)
                      .setStatus(entry.key),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<RenewalListState>(
            value: ref.watch(renewalListProvider),
            onRetry: () => ref.invalidate(renewalListProvider),
            builder: (context, list) {
              if (list.items.isEmpty) {
                return EmptyState(
                  icon: HvpIcons.ticket,
                  title:
                      filter.q.isEmpty ? 'Chưa có yêu cầu' : 'Không tìm thấy',
                  message: filter.status == 'PENDING'
                      ? 'Không có yêu cầu gia hạn nào đang chờ.'
                      : 'Không có yêu cầu nào ở trạng thái này.',
                );
              }
              return HvpRefresh(
                onRefresh: () => ref.refresh(renewalListProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      16, 8, 16, HvpLayout.navClearance),
                  itemCount: list.items.length + (list.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == list.items.length) return _MoreButton(list: list);
                    final request = list.items[i];
                    return RenewalCard(
                      request: request,
                      actions: !request.isPending
                          ? const <Widget>[]
                          : <Widget>[
                              HvpButton.gold(
                                label: widget.approveLabel,
                                icon: HvpIcons.money,
                                small: true,
                                expand: true,
                                onPressed: () =>
                                    askApproveRenewal(context, ref, request),
                              ),
                              const SizedBox(height: 8),
                              HvpButton.danger(
                                label: 'Huỷ yêu cầu',
                                icon: HvpIcons.close,
                                small: true,
                                expand: true,
                                onPressed: () =>
                                    askCancelRenewal(context, ref, request),
                              ),
                            ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.list});

  final RenewalListState list;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: <Widget>[
          if (list.loadMoreError != null)
            Text(list.loadMoreError!,
                style: context.txt.bodySmall.copyWith(color: context.hvp.red)),
          HvpButton.secondary(
            label: 'Tải thêm',
            icon: HvpIcons.caretDown,
            small: true,
            loading: list.loadingMore,
            onPressed: list.loadingMore
                ? null
                : () => ref.read(renewalListProvider.notifier).loadMore(),
          ),
        ],
      );
}
