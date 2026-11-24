import '../../../../core/widgets/status_chip.dart';

/// Centralised Vietnamese labels, [ChipTone]s and display helpers for every
/// Challenge enum value.  Import this single file instead of hard-coding
/// switch-cases across screens.

// ---------------------------------------------------------------------------
// Challenge Type (cycle)
// ---------------------------------------------------------------------------
String challengeTypeLabel(String value) => switch (value) {
      'DAILY' => 'Hằng ngày',
      'WEEKLY' => 'Hằng tuần',
      'MONTHLY' => 'Hằng tháng',
      'EVENT' => 'Sự kiện',
      _ => value,
    };

// ---------------------------------------------------------------------------
// Challenge Context
// ---------------------------------------------------------------------------
String challengeContextLabel(String value) => switch (value) {
      'SESSION' => 'Buổi tập thường',
      'WORKSHOP' => 'Chuyên đề',
      'EXAM' => 'Kỳ thi lên đai',
      _ => value,
    };

// ---------------------------------------------------------------------------
// Participation Status (student & coach screens)
// ---------------------------------------------------------------------------
String participationStatusLabel(String? value) => switch (value) {
      'PENDING_COACH' => 'Chờ duyệt tham gia',
      'JOINED' => 'Đã tham gia',
      'AWAITING_COACH' => 'Chờ duyệt hoàn thành',
      'REWARDED' => 'Đã nhận thưởng',
      'EXPIRED' => 'Đã hết hạn',
      _ => 'Chưa tham gia',
    };

ChipTone participationStatusTone(String? value) => switch (value) {
      'PENDING_COACH' => ChipTone.warning,
      'JOINED' => ChipTone.info,
      'AWAITING_COACH' => ChipTone.warning,
      'REWARDED' => ChipTone.success,
      'EXPIRED' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

// ---------------------------------------------------------------------------
// Admin Challenge Status (lifecycle)
// ---------------------------------------------------------------------------
String adminChallengeStatusLabel(String value) => switch (value) {
      'OPEN' => 'Đang mở',
      'DRAFT' => 'Nháp',
      'CLOSED' => 'Đã đóng',
      'CANCELLED' => 'Đã hủy',
      _ => value,
    };

ChipTone adminChallengeStatusTone(String value) => switch (value) {
      'OPEN' => ChipTone.success,
      'DRAFT' => ChipTone.warning,
      'CLOSED' => ChipTone.neutral,
      'CANCELLED' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

// ---------------------------------------------------------------------------
// Join Approval
// ---------------------------------------------------------------------------
String joinApprovalLabel(String value) => switch (value) {
      'AUTO' => 'Tự động duyệt',
      'COACH' => 'Coach duyệt',
      _ => value,
    };

// ---------------------------------------------------------------------------
// Completion Method
// ---------------------------------------------------------------------------
String completionMethodLabel(String value) => switch (value) {
      'ATTENDANCE' => 'Điểm danh',
      'EVIDENCE' => 'Bằng chứng (ảnh)',
      _ => value,
    };
