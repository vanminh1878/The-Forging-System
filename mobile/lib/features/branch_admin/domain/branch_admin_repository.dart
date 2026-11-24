import '../../../core/branch/branch.dart';
import 'branch_input.dart';

/// What the admin branch screens need from the backend.
abstract class BranchAdminRepository {
  /// `GET /branches?includeInactive=true` (ordered by name).
  Future<List<Branch>> getBranches();

  /// `POST /admin/branches`; without `code` the server assigns the next CNxxx.
  Future<Branch> create(BranchInput input);

  /// `PATCH /admin/branches/:id`; empty optional fields are sent as null to clear them.
  Future<Branch> update(String branchId, BranchInput input);

  /// `POST /admin/branches/:id/status`; [reason] is required by the API (3-500 characters).
  Future<Branch> setActive(String branchId,
      {required bool isActive, required String reason});
}

/// Branches to show: all, or only the active ones.
List<Branch> visibleBranches(List<Branch> all, {required bool showInactive}) =>
    showInactive ? all : all.where((b) => b.isActive).toList(growable: false);
