import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/status_chip.dart';
import 'package:hvp_forging/features/challenges/presentation/helpers/challenge_ui_helpers.dart';

void main() {
  test('Challenge UI helpers translate workflow and participation values', () {
    expect(participationStatusLabel('PENDING_COACH'), 'Chờ duyệt tham gia');
    expect(participationStatusTone('PENDING_COACH'), ChipTone.warning);
    expect(joinApprovalLabel('AUTO'), 'Tự động duyệt');
    expect(completionMethodLabel('ATTENDANCE'), 'Điểm danh');
  });

  test('Challenge UI helpers translate Admin lifecycle and context values', () {
    expect(challengeTypeLabel('WEEKLY'), 'Hằng tuần');
    expect(challengeContextLabel('WORKSHOP'), 'Chuyên đề');
    expect(adminChallengeStatusLabel('OPEN'), 'Đang mở');
    expect(adminChallengeStatusTone('CANCELLED'), ChipTone.danger);
  });
}
