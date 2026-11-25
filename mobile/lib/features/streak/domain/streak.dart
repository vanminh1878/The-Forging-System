class StreakLog {
  const StreakLog({
    required this.weekStart,
    required this.sessionsCount,
    required this.targetSessions,
    required this.result,
    required this.streakBefore,
    required this.streakAfter,
  });

  final DateTime weekStart;
  final int sessionsCount;
  final int targetSessions;
  final String result;
  final int streakBefore;
  final int streakAfter;
}

class StreakSummary {
  const StreakSummary({
    required this.currentStreakWeeks,
    required this.longestStreakWeeks,
    required this.currentWeekStart,
    required this.sessionsThisWeek,
    required this.targetSessions,
    required this.availableFreezes,
    required this.milestones,
    required this.logs,
  });

  final int currentStreakWeeks;
  final int longestStreakWeeks;
  final DateTime currentWeekStart;
  final int sessionsThisWeek;
  final int targetSessions;
  final int availableFreezes;
  final Map<int, int> milestones;
  final List<StreakLog> logs;
}

abstract interface class StreakRepository {
  Future<StreakSummary> summary();
}
