enum StaffRole {
  coach('COACH', 'Coach'),
  headCoach('HEAD_COACH', 'Head Coach'),
  receptionist('RECEPTIONIST', 'Lễ tân'),
  admin('ADMIN', 'Admin'),
  superAdmin('SUPER_ADMIN', 'Super Admin');

  const StaffRole(this.wire, this.label);
  final String wire;
  final String label;

  static String labelOf(String code) =>
      values
          .where((role) => role.wire == code)
          .map((role) => role.label)
          .firstOrNull ??
      code;
}

enum StaffStatus {
  active('ACTIVE', 'Hoạt động'),
  locked('LOCKED', 'Đã khóa'),
  disabled('DISABLED', 'Vô hiệu hóa');

  const StaffStatus(this.wire, this.label);
  final String wire;
  final String label;

  static String labelOf(String code) =>
      values
          .where((status) => status.wire == code)
          .map((status) => status.label)
          .firstOrNull ??
      code;
}

class StaffMember {
  const StaffMember(
      {required this.id,
      required this.fullName,
      required this.roles,
      required this.accountStatus,
      this.phone,
      this.email,
      this.branchId,
      this.branchName,
      this.mustChangePassword = false});

  final String id;
  final String fullName;
  final List<String> roles;
  final String accountStatus;
  final String? phone;
  final String? email;
  final String? branchId;
  final String? branchName;
  final bool mustChangePassword;
  String get roleLabel => roles.map(StaffRole.labelOf).join(' · ');
}

class StaffQuery {
  const StaffQuery(
      {this.q = '',
      this.role,
      this.status,
      this.branchId,
      this.page = 1,
      this.limit = 20});

  final String q;
  final StaffRole? role;
  final StaffStatus? status;
  final String? branchId;
  final int page;
  final int limit;
  int get activeFilters =>
      (role == null ? 0 : 1) +
      (status == null ? 0 : 1) +
      (branchId == null ? 0 : 1);

  StaffQuery withPage(int value) => StaffQuery(
      q: q,
      role: role,
      status: status,
      branchId: branchId,
      page: value,
      limit: limit);
  StaffQuery withSearch(String value) => StaffQuery(
      q: value.trim(),
      role: role,
      status: status,
      branchId: branchId,
      limit: limit);

  @override
  bool operator ==(Object other) =>
      other is StaffQuery &&
      other.q == q &&
      other.role == role &&
      other.status == status &&
      other.branchId == branchId &&
      other.page == page &&
      other.limit == limit;
  @override
  int get hashCode => Object.hash(q, role, status, branchId, page, limit);
}

class StaffPage {
  const StaffPage(
      {required this.items,
      required this.page,
      required this.total,
      required this.totalPages});
  final List<StaffMember> items;
  final int page;
  final int total;
  final int totalPages;
  bool get hasMore => page < totalPages;
}

class StaffBranch {
  const StaffBranch(this.id, this.name);
  final String id;
  final String name;
}

class UpdateStaffInput {
  const UpdateStaffInput({
    required this.role,
    required this.branchId,
    required this.reason,
  });

  final StaffRole role;
  final String branchId;
  final String reason;
}
