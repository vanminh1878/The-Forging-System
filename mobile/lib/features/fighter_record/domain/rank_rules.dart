import '../../../core/utils/formatters.dart';
import 'badge_models.dart';
import 'rank_models.dart';

/// Pure business rules of the Fighter Record screens (unit tested).

/// `GET /me/rank` does not return the DP balance, so it is derived from the
/// distance to the next threshold. Exact while DP is short of the next rank;
/// once the threshold is met the exact value is not exposed and the threshold
/// is used (the gauge is full anyway).
int estimateDp(RankProgress progress) {
  final next = progress.next;
  if (next == null) return progress.current.dpThreshold;
  if (progress.dpRemaining > 0) return next.dpThreshold - progress.dpRemaining;
  return next.dpThreshold;
}

/// True when [next] shows a higher rank than [previous] (celebrate!).
bool isRankUp(RankProgress? previous, RankProgress next) {
  if (previous == null) return false;
  return next.current.order > previous.current.order;
}

/// The member may press "Yêu cầu Rank Trial".
bool canRequestTrial(RankProgress progress) => progress.status == RankStatus.trialRequired;

enum RequirementKind { dp, time, course, trial }

/// One line of the "Điều kiện lên hạng" checklist.
class Requirement {
  const Requirement({required this.kind, required this.title, required this.detail, required this.met});

  final RequirementKind kind;
  final String title;
  final String detail;
  final bool met;
}

/// `2,5 tháng`, `1 tháng`: whole months drop the decimal.
String formatMonths(double months) {
  final rounded = (months * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return '${rounded.round()} tháng';
  return '${formatDecimal1(rounded)} tháng';
}

/// Checklist of the gates for the next rank. Empty at the highest rank.
List<Requirement> buildRequirements(RankProgress progress) {
  final next = progress.next;
  if (next == null) return const <Requirement>[];
  final list = <Requirement>[
    Requirement(
      kind: RequirementKind.dp,
      title: 'Đạt ${formatInt(next.dpThreshold)} DP',
      detail: progress.dpOk ? 'Đã đủ điểm DP' : 'Còn thiếu ${formatInt(progress.dpRemaining)} DP',
      met: progress.dpOk,
    ),
  ];
  if (next.minActiveMonths > 0) {
    list.add(
      Requirement(
        kind: RequirementKind.time,
        title: 'Tập luyện tối thiểu ${next.minActiveMonths} tháng',
        detail: progress.timeOk
            ? 'Bạn đã tập ${formatMonths(progress.monthsIn)}'
            : 'Còn ${formatMonths(progress.monthsRemaining)} nữa',
        met: progress.timeOk,
      ),
    );
  }
  if (!progress.courseOk || progress.missingCourses.isNotEmpty) {
    final names = progress.missingCourses.map((c) => c.name).join(', ');
    list.add(
      Requirement(
        kind: RequirementKind.course,
        title: 'Hoàn thành khóa bắt buộc',
        detail: names.isEmpty ? 'Còn khóa chưa hoàn thành' : 'Còn thiếu: $names',
        met: false,
      ),
    );
  }
  if (progress.trialRequired) {
    final status = progress.trialStatus;
    final String detail;
    if (status == TrialStatus.passed) {
      detail = 'Đã vượt qua Rank Trial';
    } else if (status == TrialStatus.pending || status == TrialStatus.scheduled) {
      detail = 'Yêu cầu đang chờ huấn luyện viên chấm';
    } else if (status == TrialStatus.failed) {
      detail = 'Lần trước chưa đạt - bạn có thể yêu cầu lại';
    } else {
      detail = 'Cần huấn luyện viên chấm trực tiếp';
    }
    list.add(
      Requirement(
        kind: RequirementKind.trial,
        title: 'Vượt qua Rank Trial',
        detail: detail,
        met: status == TrialStatus.passed,
      ),
    );
  }
  return list;
}

/// Visual state of one of the 7 slots on the badge board.
enum BadgeSlotState { earned, locked, revoked }

class BadgeSlot {
  const BadgeSlot({required this.rank, required this.state, this.earnedAt, this.reason});

  final RankInfo rank;
  final BadgeSlotState state;
  final DateTime? earnedAt;
  final String? reason;
}

/// One slot per rank (lowest first): held badge -> earned; a rank whose badge
/// was removed by a demotion and not regained -> revoked; otherwise locked.
List<BadgeSlot> buildBadgeSlots({
  required List<RankInfo> ranks,
  required List<EarnedBadge> badges,
  required List<RankHistoryEntry> history,
}) {
  final sorted = [...ranks]..sort((a, b) => a.order.compareTo(b.order));
  final held = {for (final b in badges) b.rankId: b};
  final revokedIds = {
    for (final h in history)
      if (h.isRevoked) h.toRankId,
  };
  return [
    for (final rank in sorted)
      if (held.containsKey(rank.id))
        BadgeSlot(
          rank: rank,
          state: BadgeSlotState.earned,
          earnedAt: held[rank.id]!.earnedAt,
          reason: held[rank.id]!.reason,
        )
      else if (revokedIds.contains(rank.id))
        BadgeSlot(rank: rank, state: BadgeSlotState.revoked)
      else
        BadgeSlot(rank: rank, state: BadgeSlotState.locked),
  ];
}

/// Everything the "Huy hiệu" tab renders.
class BadgeBoard {
  const BadgeBoard({required this.slots, required this.history, required this.ranksById});

  final List<BadgeSlot> slots;
  final List<RankHistoryEntry> history;
  final Map<String, RankInfo> ranksById;

  int get earnedCount => slots.where((s) => s.state == BadgeSlotState.earned).length;
}

BadgeBoard buildBadgeBoard({
  required List<RankInfo> ranks,
  required List<EarnedBadge> badges,
  required List<RankHistoryEntry> history,
}) {
  return BadgeBoard(
    slots: buildBadgeSlots(ranks: ranks, badges: badges, history: history),
    history: history,
    ranksById: {for (final r in ranks) r.id: r},
  );
}

/// Timeline title: `Tự động lên hạng: THE FORGED`, or `Mất huy hiệu THE FORGED`.
String historyTitle(RankHistoryEntry entry, String rankName) =>
    entry.isRevoked ? 'Mất huy hiệu $rankName' : '${entry.via.label}: $rankName';
