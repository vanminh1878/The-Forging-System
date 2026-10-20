import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/staff_repository_impl.dart';
import '../domain/staff_models.dart';
import '../domain/staff_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
    (ref) => StaffRepositoryImpl(ref.watch(apiClientProvider)));

// Query-keyed providers drop stale responses automatically when filters change.
final staffPageProvider =
    FutureProvider.autoDispose.family<StaffPage, StaffQuery>((ref, query) {
  ref.watch(currentUserIdProvider);
  return ref.watch(staffRepositoryProvider).search(query);
});

final staffBranchesProvider =
    FutureProvider.autoDispose<List<StaffBranch>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(staffRepositoryProvider).branches();
});
