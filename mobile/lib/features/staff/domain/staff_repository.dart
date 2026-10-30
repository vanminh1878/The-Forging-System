import 'staff_models.dart';

abstract interface class StaffRepository {
  Future<StaffPage> search(StaffQuery query);
  Future<List<StaffBranch>> branches();
  Future<CreatedStaff> create(CreateStaffInput input);
}
