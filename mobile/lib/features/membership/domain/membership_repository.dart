import 'membership_models.dart';
import 'package_class_option.dart';

/// What the "Gói tập" screen needs from the backend.
abstract class MembershipRepository {
  /// `GET /me/membership`
  Future<MyMembership> getMyMembership();

  /// `GET /package-types`: every package on sale.
  Future<List<PackageType>> listPackageTypes();

  /// `GET /package-types/:id/classes`: the active classes of a package.
  Future<List<PackageClassOption>> listPackageClasses(String packageTypeId);

  /// `POST /me/renewal-requests`. [classId] is required when the package has
  /// classes.
  Future<void> requestRenewal(
      {required String packageTypeId, String? classId, String? note});

  /// `GET /me/renewal-requests`, newest first. First page only (limit 50).
  Future<List<RenewalRequest>> listMyRenewalRequests();
}
