import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../membership/domain/membership_models.dart';
import '../../data/package_admin_api.dart';
import '../../data/package_admin_repository_impl.dart';
import '../../domain/package_admin_repository.dart';

/// Tests override this with a fake repository.
final packageAdminRepositoryProvider = Provider<PackageAdminRepository>(
  (ref) =>
      PackageAdminRepositoryImpl(PackageAdminApi(ref.watch(apiClientProvider))),
);

/// Every package, including the ones no longer on sale.
final adminPackagesProvider =
    FutureProvider.autoDispose<List<PackageType>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(packageAdminRepositoryProvider).list();
});

final packageSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
