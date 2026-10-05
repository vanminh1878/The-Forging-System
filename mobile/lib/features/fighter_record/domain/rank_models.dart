/// Rank progression entities. Pure Dart: no Flutter, no JSON.
library;

/// One of the 7 ranks (`GET /ranks`, or embedded in `GET /me/rank`).
class RankInfo {
  const RankInfo({
    required this.id,
    required this.order,
    required this.code,
    required this.nameEn,
    required this.dpThreshold,
    required this.minActiveMonths,
    this.nameVi,
    this.requiresTrial = false,
    this.isHonorary = false,
  });

  final String id;

  /// 1..7, lowest to highest.
  final int order;
  final String code;
  final String nameEn;
  final String? nameVi;
  final int dpThreshold;
  final int minActiveMonths;
  final bool requiresTrial;
  final bool isHonorary;

  /// `THE FORGED`; falls back to the code when the API sends no English name.
  String get displayName => nameEn.isNotEmpty ? nameEn : code.replaceAll('_', ' ');
}

/// Server-computed position of the member on the rank ladder.
enum RankStatus {
  maxRank,
  inProgress,
  rankReady,
  trialRequired,
  trialPending;

  static RankStatus parse(String? value) {
    switch (value) {
      case 'MAX_RANK':
        return RankStatus.maxRank;
      case 'RANK_READY':
        return RankStatus.rankReady;
      case 'TRIAL_REQUIRED':
        return RankStatus.trialRequired;
      case 'TRIAL_PENDING':
        return RankStatus.trialPending;
      default:
        return RankStatus.inProgress;
    }
  }
}

/// Status of the member's latest Rank Trial request for the next rank.
enum TrialStatus {
  notRequested,
  pending,
  scheduled,
  passed,
  failed,
  cancelled;

  static TrialStatus? parse(String? value) {
    switch (value) {
      case 'NOT_REQUESTED':
        return TrialStatus.notRequested;
      case 'PENDING':
        return TrialStatus.pending;
      case 'SCHEDULED':
        return TrialStatus.scheduled;
      case 'PASSED':
        return TrialStatus.passed;
      case 'FAILED':
        return TrialStatus.failed;
      case 'CANCELLED':
        return TrialStatus.cancelled;
      default:
        return null;
    }
  }
}

class MissingCourse {
  const MissingCourse({required this.id, required this.name});

  final String id;
  final String name;
}

/// `GET /me/rank`.
class RankProgress {
  const RankProgress({
    required this.current,
    required this.status,
    required this.dpOk,
    required this.timeOk,
    required this.courseOk,
    required this.dpRemaining,
    required this.monthsIn,
    required this.monthsRemaining,
    required this.trialRequired,
    required this.trialWaived,
    required this.peakRankOrder,
    this.next,
    this.trialStatus,
    this.missingCourses = const <MissingCourse>[],
  });

  final RankInfo current;

  /// Null at the highest rank.
  final RankInfo? next;
  final RankStatus status;
  final bool dpOk;
  final bool timeOk;
  final bool courseOk;
  final int dpRemaining;
  final double monthsIn;
  final double monthsRemaining;
  final bool trialRequired;

  /// True when the next rank was reached before (no new trial needed).
  final bool trialWaived;
  final TrialStatus? trialStatus;
  final List<MissingCourse> missingCourses;
  final int peakRankOrder;

  bool get isMaxRank => next == null;
}
