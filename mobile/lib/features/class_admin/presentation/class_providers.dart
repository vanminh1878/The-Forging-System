import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/class_repository_impl.dart';
import '../domain/class_models.dart';
import '../domain/class_repository.dart';

final classRepositoryProvider = Provider<ClassRepository>(
    (ref) => ClassRepositoryImpl(ref.watch(apiClientProvider)));

final classPageProvider =
    FutureProvider.autoDispose.family<ClassPage, ClassQuery>((ref, query) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).list(query);
});

/// The signed-in coach's own classes.
final coachClassesProvider =
    FutureProvider.autoDispose<List<ClassSummary>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).coachClasses();
});

final classCoachesProvider =
    FutureProvider.autoDispose<List<ClassCoach>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).coaches();
});

final classSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

final classDetailProvider =
    FutureProvider.autoDispose.family<ClassDetail, String>((ref, id) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).detail(id);
});

final classSessionsProvider = FutureProvider.autoDispose
    .family<List<ClassSession>, String>((ref, classId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).sessions(classId);
});
