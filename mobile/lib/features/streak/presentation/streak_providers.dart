import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../data/streak_repository_impl.dart';
import '../domain/streak.dart';

final streakRepositoryProvider = Provider<StreakRepository>(
  (ref) => StreakRepositoryImpl(ref.watch(apiClientProvider)),
);

final streakSummaryProvider = FutureProvider.autoDispose<StreakSummary>(
  (ref) => ref.watch(streakRepositoryProvider).summary(),
);
