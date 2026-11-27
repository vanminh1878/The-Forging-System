import '../../fighter_record/domain/points_models.dart';
import '../../reception_checkin/domain/member_hit.dart';

abstract interface class AdminPointsRepository {
  Future<MemberSearchResult> searchMembers(String query);
  Future<PointsPage> ledger(String memberId, {int page = 1});
  Future<MonthlyPointStatus> monthlyStatus(String memberId);
  Future<void> adjust(
    String memberId, {
    required int dpDelta,
    required int marksDelta,
    required String reason,
    bool confirmed = false,
  });
  Future<void> reverse(String transactionId, {required String reason});
}
