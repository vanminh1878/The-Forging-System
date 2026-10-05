import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/fighter_record_api.dart';
import '../../data/fighter_record_repository_impl.dart';
import '../../domain/badge_models.dart';
import '../../domain/fighter_record_repository.dart';
import '../../domain/points_models.dart';
import '../../domain/rank_models.dart';
import '../../domain/rank_rules.dart';

/// Tests override this with a fake repository.
final fighterRecordRepositoryProvider = Provider<FighterRecordRepository>(
  (ref) => FighterRecordRepositoryImpl(FighterRecordApi(ref.watch(apiClientProvider))),
);

/// "Lên hạng" tab. Watching the user id drops cached data on account switch.
final rankProgressProvider = FutureProvider.autoDispose<RankProgress>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(fighterRecordRepositoryProvider).getProgress();
});

/// "Huy hiệu" tab: ranks + held badges + timeline, loaded together.
final badgeBoardProvider = FutureProvider.autoDispose<BadgeBoard>((ref) async {
  ref.watch(currentUserIdProvider);
  final repo = ref.watch(fighterRecordRepositoryProvider);
  final results = await Future.wait<Object>(<Future<Object>>[
    repo.getRanks(),
    repo.getBadges(),
    repo.getHistory(),
  ]);
  return buildBadgeBoard(
    ranks: results[0] as List<RankInfo>,
    badges: results[1] as List<EarnedBadge>,
    history: results[2] as List<RankHistoryEntry>,
  );
});

/// Monthly cap usage shown above the ledger.
final monthlyPointsProvider = FutureProvider.autoDispose<MonthlyPointStatus>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(fighterRecordRepositoryProvider).getMonthlyStatus();
});

/// Selected ledger filter (null = all sources).
class LedgerFilterNotifier extends Notifier<PointSource?> {
  @override
  PointSource? build() {
    ref.watch(currentUserIdProvider); // a new account starts unfiltered
    return null;
  }

  void select(PointSource? source) => state = source;
}

final ledgerFilterProvider = NotifierProvider<LedgerFilterNotifier, PointSource?>(LedgerFilterNotifier.new);

/// "Rank Trial" request submission (progress / error for the button).
final trialRequestProvider = NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
