import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../providers/fighter_record_providers.dart';
import '../providers/ledger_notifier.dart';
import 'ledger_filter_bar.dart';
import 'ledger_slivers.dart';
import 'monthly_cap_card.dart';

/// Tab "Sổ điểm": monthly caps, source filter and the paginated ledger.
class PointsTab extends ConsumerWidget {
  const PointsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(monthlyPointsProvider);
    return HvpRefresh(
      onRefresh: () async {
        ref.invalidate(monthlyPointsProvider);
        ref.invalidate(ledgerProvider);
        await ref.read(ledgerProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            sliver: SliverToBoxAdapter(
              child: monthly.when<Widget>(
                loading: () => const ShimmerBox(height: 120, radius: 10),
                error: (error, _) => SizedBox(
                  height: 220,
                  child: ErrorState.fromError(error, onRetry: () => ref.invalidate(monthlyPointsProvider)),
                ),
                data: (status) => MonthlyCapCard(status: status),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: LedgerFilterBar()),
          const LedgerSlivers(),
        ],
      ),
    );
  }
}
