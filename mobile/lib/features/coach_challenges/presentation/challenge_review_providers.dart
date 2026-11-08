import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/challenge_review_repository.dart';
import '../domain/challenge_review.dart';

final challengeReviewRepositoryProvider = Provider<ChallengeReviewRepository>(
  (ref) => ChallengeReviewRepositoryImpl(ref.watch(apiClientProvider)),
);
final challengeReviewQueueProvider = FutureProvider.autoDispose.family<ChallengeReviewPage, ({String? status, String? evidence, String query, int page})>(
  (ref, filter) => ref.watch(challengeReviewRepositoryProvider).list(
    status: filter.status, evidence: filter.evidence, query: filter.query, page: filter.page,
  ),
);
final challengeReviewActionProvider = NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
