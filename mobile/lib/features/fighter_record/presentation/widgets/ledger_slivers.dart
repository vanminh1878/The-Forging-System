import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/design/hvp_context.dart';
import '../providers/fighter_record_providers.dart';
import '../providers/ledger_notifier.dart';
import 'transaction_tile.dart';

/// The ledger list of the "Sổ điểm" tab as slivers: loading, error, empty,
/// rows and the "load more" footer.
class LedgerSlivers extends ConsumerWidget {
  const LedgerSlivers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    return ledger.when<Widget>(
      loading: () => const SliverToBoxAdapter(child: _LedgerSkeleton()),
      error: (error, _) => SliverToBoxAdapter(
        child: ErrorState.fromError(error, onRetry: () => ref.invalidate(ledgerProvider)),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          final filtered = ref.watch(ledgerFilterProvider) != null;
          return SliverToBoxAdapter(
            child: EmptyState(
              icon: HvpIcons.receipt,
              title: 'Chưa có giao dịch',
              message: filtered
                  ? 'Không có giao dịch nào thuộc nhóm này.'
                  : 'Điểm DP và Marks của bạn sẽ hiện ở đây sau mỗi buổi tập.',
              actionLabel: filtered ? 'Xem tất cả' : null,
              onAction: filtered ? () => ref.read(ledgerFilterProvider.notifier).select(null) : null,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.items.length) return _LoadMoreFooter(state: state);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TransactionTile(transaction: state.items[index]).entrance(index),
                );
              },
              childCount: state.items.length + (state.hasMore ? 1 : 0),
            ),
          ),
        );
      },
    );
  }
}

class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter({required this.state});

  final LedgerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ledgerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: <Widget>[
          if (state.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(state.loadMoreError!, style: context.txt.bodySmall, textAlign: TextAlign.center),
            ),
          HvpButton.secondary(
            label: state.loadMoreError != null ? 'Thử lại' : 'Xem thêm',
            icon: state.loadMoreError != null ? HvpIcons.retry : HvpIcons.caretDown,
            small: true,
            loading: state.loadingMore,
            onPressed: notifier.loadMore,
          ),
        ],
      ),
    );
  }
}

class _LedgerSkeleton extends StatelessWidget {
  const _LedgerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ShimmerBox(height: 68, radius: 10),
            ),
        ],
      ),
    );
  }
}
