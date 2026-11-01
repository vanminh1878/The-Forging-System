import '../domain/membership_models.dart';
import '../domain/membership_repository.dart';
import 'dto/membership_dto.dart';
import 'membership_api.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl(this._api);

  final MembershipApi _api;

  @override
  Future<MyMembership> getMyMembership() async =>
      myMembershipFromJson((await _api.mine()).dataMap);
}
