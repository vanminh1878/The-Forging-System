import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../fighter_record/domain/points_models.dart';
import '../../reception_checkin/domain/member_hit.dart';
import '../data/admin_points_repository_impl.dart';
import '../domain/admin_points_repository.dart';

final adminPointsRepositoryProvider = Provider<AdminPointsRepository>(
  (ref) => AdminPointsRepositoryImpl(ref.watch(apiClientProvider)),
);

final adminPointsSearchProvider =
    FutureProvider.autoDispose.family<MemberSearchResult, String>(
  (ref, query) => ref.watch(adminPointsRepositoryProvider).searchMembers(query),
);

final adminPointsLedgerProvider =
    FutureProvider.autoDispose.family<PointsPage, String>(
  (ref, memberId) => ref.watch(adminPointsRepositoryProvider).ledger(memberId),
);

final adminPointsMonthlyProvider =
    FutureProvider.autoDispose.family<MonthlyPointStatus, String>(
  (ref, memberId) =>
      ref.watch(adminPointsRepositoryProvider).monthlyStatus(memberId),
);
