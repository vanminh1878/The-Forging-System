import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/membership_api.dart';
import '../../data/membership_repository_impl.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_repository.dart';
import '../../domain/package_class_option.dart';

/// Tests override this with a fake repository.
final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) =>
      MembershipRepositoryImpl(MembershipApi(ref.watch(apiClientProvider))),
);

/// Watching the user id drops cached data on account switch.
final myMembershipProvider = FutureProvider.autoDispose<MyMembership>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(membershipRepositoryProvider).getMyMembership();
});

/// Packages on sale for the picker.
final packageTypesProvider = FutureProvider.autoDispose<List<PackageType>>(
    (ref) => ref.watch(membershipRepositoryProvider).listPackageTypes());

/// Which package, and (staff only) which learner the `enrolled` flag is for.
typedef PackageClassesKey = ({String packageTypeId, String? memberId});

/// Active classes of one package, for the "choose a class" step.
final packageClassesProvider = FutureProvider.autoDispose
    .family<List<PackageClassOption>, PackageClassesKey>((ref, key) => ref
        .watch(membershipRepositoryProvider)
        .listPackageClasses(key.packageTypeId, memberId: key.memberId));

final renewalSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

/// First page of the member's renewal requests (newest first).
final myRenewalRequestsProvider =
    FutureProvider.autoDispose<List<RenewalRequest>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(membershipRepositoryProvider).listMyRenewalRequests();
});
