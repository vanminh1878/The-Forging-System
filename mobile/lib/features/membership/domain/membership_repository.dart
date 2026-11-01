import 'membership_models.dart';

/// What the "Gói tập" screen needs from the backend.
abstract class MembershipRepository {
  /// `GET /me/membership`
  Future<MyMembership> getMyMembership();
}
