import '../../membership/domain/membership_models.dart';
import 'package_models.dart';

/// Admin package management (PKG-01).
abstract interface class PackageAdminRepository {
  /// `GET /package-types?includeInactive=true`
  Future<List<PackageType>> list();

  /// `POST /admin/package-types`
  Future<PackageType> create(PackageDraft draft);

  /// `PATCH /admin/package-types/:id` with only the changed fields.
  Future<PackageType> update(String id, Map<String, Object?> changes);
}
