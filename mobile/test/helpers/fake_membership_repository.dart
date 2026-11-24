import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/domain/membership_repository.dart';
import 'package:hvp_forging/features/membership/domain/package_class_option.dart';

/// Scripted [MembershipRepository]; unset calls fail loudly.
class FakeMembershipRepository implements MembershipRepository {
  FakeMembershipRepository(
    this.membership, {
    this.packages,
    this.request,
    this.history,
    this.classes,
  });

  final Future<MyMembership> Function() membership;
  final Future<List<PackageType>> Function()? packages;
  final Future<void> Function(String packageTypeId, String? note)? request;

  /// Classes per package id; a missing key means the package has no classes.
  final Future<List<PackageClassOption>> Function(String packageTypeId)?
      classes;
  final Future<List<RenewalRequest>> Function()? history;

  int membershipCalls = 0;
  int packageCalls = 0;
  int historyCalls = 0;
  int classCalls = 0;
  final List<String?> classMemberIds = <String?>[];
  final List<({String packageTypeId, String? classId, String? note})> requests =
      <({String packageTypeId, String? classId, String? note})>[];

  @override
  Future<MyMembership> getMyMembership() {
    membershipCalls++;
    return membership();
  }

  @override
  Future<List<PackageType>> listPackageTypes() {
    packageCalls++;
    return packages!();
  }

  @override
  Future<List<PackageClassOption>> listPackageClasses(String packageTypeId,
      {String? memberId}) {
    classCalls++;
    classMemberIds.add(memberId);
    return classes == null
        ? Future<List<PackageClassOption>>.value(const <PackageClassOption>[])
        : classes!(packageTypeId);
  }

  @override
  Future<void> requestRenewal(
      {required String packageTypeId, String? classId, String? note}) async {
    requests.add((packageTypeId: packageTypeId, classId: classId, note: note));
    await request!(packageTypeId, note);
  }

  @override
  Future<List<RenewalRequest>> listMyRenewalRequests() {
    historyCalls++;
    return history == null
        ? Future<List<RenewalRequest>>.value(const <RenewalRequest>[])
        : history!();
  }
}
