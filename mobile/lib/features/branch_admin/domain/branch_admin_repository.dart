import '../../../core/branch/branch.dart';

/// What the admin branch screens need from the backend.
abstract class BranchAdminRepository {
  /// `GET /branches?includeInactive=true` (ordered by name).
  Future<List<Branch>> getBranches();
}

/// Branches to show: all, or only the active ones.
List<Branch> visibleBranches(List<Branch> all, {required bool showInactive}) =>
    showInactive ? all : all.where((b) => b.isActive).toList(growable: false);
