import '../../../core/utils/json_utils.dart';
import '../domain/staff_models.dart';

StaffMember staffMemberFromJson(JsonMap json) => StaffMember(
      id: str(json, 'id'),
      fullName: str(json, 'fullName'),
      roles: stringList(json['roles']),
      accountStatus: str(json, 'accountStatus'),
      phone: strOrNull(json, 'phone'),
      email: strOrNull(json, 'email'),
      branchId: strOrNull(json, 'branchId'),
      branchName: strOrNull(json, 'branchName'),
      mustChangePassword: boolOf(json, 'mustChangePassword'),
    );
