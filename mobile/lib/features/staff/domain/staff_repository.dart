import 'staff_models.dart';

abstract interface class StaffRepository {
  Future<StaffPage> search(StaffQuery query);
  Future<List<StaffBranch>> branches();
  Future<StaffMember> update(String staffId, UpdateStaffInput input);
  Future<StaffMember> setStatus(String staffId,
      {required StaffStatus status, required String reason});
}
