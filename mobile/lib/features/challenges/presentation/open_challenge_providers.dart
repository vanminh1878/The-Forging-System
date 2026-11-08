import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/open_challenge_repository.dart';
import '../domain/open_challenge.dart';

final openChallengeRepositoryProvider = Provider<OpenChallengeRepository>(
  (ref) => OpenChallengeRepositoryImpl(ref.watch(apiClientProvider)),
);

final openChallengesProvider = FutureProvider.autoDispose
    .family<OpenChallengePage, ({String? type, int page})>((ref, query) {
      ref.watch(currentUserIdProvider);
      return ref
          .watch(openChallengeRepositoryProvider)
          .list(challengeType: query.type, page: query.page);
    });

final joinChallengeActionProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
