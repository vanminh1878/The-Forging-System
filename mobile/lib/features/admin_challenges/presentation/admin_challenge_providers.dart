import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/admin_challenge_repository.dart';
import '../domain/admin_challenge.dart';

final adminChallengeRepositoryProvider = Provider<AdminChallengeRepository>(
    (ref) => AdminChallengeRepositoryImpl(ref.watch(apiClientProvider)));
final adminChallengeListProvider = FutureProvider.autoDispose
    .family<AdminChallengePage, ({String query, String? status, int page})>(
        (ref, filter) => ref.watch(adminChallengeRepositoryProvider).list(
            query: filter.query, status: filter.status, page: filter.page));
final adminChallengeSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
