import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/membership_api.dart';
import '../../data/membership_repository_impl.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_repository.dart';

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
