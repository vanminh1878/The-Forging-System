import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';

final armoryCatalogRepositoryProvider = Provider<ArmoryCatalogRepository>(
    (ref) => ArmoryCatalogRepositoryImpl(ref.watch(apiClientProvider)));
final armoryTiersProvider = FutureProvider.autoDispose<List<ArmoryTier>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(armoryCatalogRepositoryProvider).tiers();
});
final armoryRewardsProvider = FutureProvider.autoDispose
    .family<RewardPage, ({String? tierCode, int page})>((ref, query) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(armoryCatalogRepositoryProvider)
      .rewards(tierCode: query.tierCode, page: query.page);
});
