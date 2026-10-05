import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/fighter_record/domain/badge_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/rank_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/rank_rules.dart';

import 'fixtures.dart';

void main() {
  group('estimateDp', () {
    test('is exact while DP is short of the next threshold', () {
      // Next threshold 3000, 400 missing -> 2600.
      expect(estimateDp(sampleProgress(dpRemaining: 400)), 2600);
    });

    test('uses the threshold once it is reached, and the current threshold at max rank', () {
      expect(estimateDp(sampleProgress(dpRemaining: 0, dpOk: true)), 3000);
      expect(estimateDp(sampleProgress(currentOrder: 7, withNext: false, status: RankStatus.maxRank)), 20000);
    });
  });

  group('isRankUp', () {
    test('only when the current rank order increased', () {
      final before = sampleProgress();
      final after = sampleProgress(currentOrder: 4);
      expect(isRankUp(before, after), isTrue);
      expect(isRankUp(after, before), isFalse);
      expect(isRankUp(before, sampleProgress(dpRemaining: 100)), isFalse);
    });

    test('never on the first load', () {
      expect(isRankUp(null, sampleProgress()), isFalse);
    });
  });

  test('canRequestTrial only for TRIAL_REQUIRED', () {
    expect(canRequestTrial(sampleProgress(status: RankStatus.trialRequired)), isTrue);
    for (final status in <RankStatus>[
      RankStatus.inProgress,
      RankStatus.rankReady,
      RankStatus.trialPending,
      RankStatus.maxRank,
    ]) {
      expect(canRequestTrial(sampleProgress(status: status)), isFalse, reason: status.name);
    }
  });

  group('formatMonths', () {
    test('whole months drop the decimal, others use a comma', () {
      expect(formatMonths(3), '3 tháng');
      expect(formatMonths(2.04), '2 tháng');
      expect(formatMonths(1.5), '1,5 tháng');
      expect(formatMonths(0), '0 tháng');
    });
  });

  group('buildRequirements', () {
    test('lists DP, time and trial for the next rank', () {
      final list = buildRequirements(sampleProgress());
      expect(list.map((r) => r.kind), <RequirementKind>[
        RequirementKind.dp,
        RequirementKind.time,
        RequirementKind.trial,
      ]);
      expect(list[0].title, 'Đạt 3.000 DP');
      expect(list[0].met, isFalse);
      expect(list[0].detail, 'Còn thiếu 400 DP');
      expect(list[1].met, isTrue);
      expect(list[1].detail, contains('4,5 tháng'));
      expect(list[2].met, isFalse);
    });

    test('missing courses are named', () {
      final list = buildRequirements(
        sampleProgress(
          courseOk: false,
          missingCourses: const <MissingCourse>[MissingCourse(id: 'c1', name: 'Boxing nền tảng')],
        ),
      );
      final course = list.singleWhere((r) => r.kind == RequirementKind.course);
      expect(course.met, isFalse);
      expect(course.detail, contains('Boxing nền tảng'));
    });

    test('trial requirement follows the trial status', () {
      Requirement trial(TrialStatus? s) =>
          buildRequirements(sampleProgress(trialStatus: s)).singleWhere((r) => r.kind == RequirementKind.trial);
      expect(trial(TrialStatus.passed).met, isTrue);
      expect(trial(TrialStatus.pending).detail, contains('chờ'));
      expect(trial(TrialStatus.failed).detail, contains('yêu cầu lại'));
      expect(trial(null).met, isFalse);
    });

    test('no trial line when the trial is waived or not needed', () {
      final list = buildRequirements(sampleProgress(trialRequired: false));
      expect(list.any((r) => r.kind == RequirementKind.trial), isFalse);
    });

    test('empty at the highest rank', () {
      expect(buildRequirements(sampleProgress(currentOrder: 7, withNext: false)), isEmpty);
    });
  });

  group('buildBadgeSlots', () {
    final ranks = sampleRanks();

    test('earned, revoked and locked slots in rank order', () {
      final slots = buildBadgeSlots(
        ranks: ranks.reversed.toList(),
        badges: <EarnedBadge>[
          EarnedBadge(rankId: 'r1', rankOrder: 1, earnedAt: DateTime.utc(2026, 1, 1)),
          EarnedBadge(rankId: 'r2', rankOrder: 2, earnedAt: DateTime.utc(2026, 3, 1)),
        ],
        history: <RankHistoryEntry>[
          RankHistoryEntry(
            id: 'h1',
            toRankId: 'r3',
            via: RankEarnVia.autoDemote,
            reason: 'DP thấp',
            dpAtChange: 1400,
            isRevoked: true,
            earnedAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );
      expect(slots.map((s) => s.rank.order), <int>[1, 2, 3, 4, 5, 6, 7]);
      expect(slots[0].state, BadgeSlotState.earned);
      expect(slots[1].state, BadgeSlotState.earned);
      expect(slots[2].state, BadgeSlotState.revoked);
      expect(slots.skip(3).every((s) => s.state == BadgeSlotState.locked), isTrue);
    });

    test('a regained badge wins over an old revoked row', () {
      final board = buildBadgeBoard(
        ranks: ranks,
        badges: <EarnedBadge>[
          EarnedBadge(rankId: 'r3', rankOrder: 3, earnedAt: DateTime.utc(2026, 7, 1)),
        ],
        history: <RankHistoryEntry>[
          RankHistoryEntry(
            id: 'h1',
            toRankId: 'r3',
            via: RankEarnVia.autoDemote,
            reason: '',
            dpAtChange: 0,
            isRevoked: true,
            earnedAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );
      expect(board.slots[2].state, BadgeSlotState.earned);
      expect(board.earnedCount, 1);
      expect(board.ranksById['r3']!.code, 'THE_DISCIPLINED');
    });
  });

  test('historyTitle', () {
    const upgrade = RankHistoryEntry(
      id: 'h',
      toRankId: 'r4',
      via: RankEarnVia.autoUpgrade,
      reason: '',
      dpAtChange: 0,
      isRevoked: false,
      earnedAt: null,
    );
    expect(historyTitle(upgrade, 'THE FORGED'), 'Tự động lên hạng: THE FORGED');
    const lost = RankHistoryEntry(
      id: 'h',
      toRankId: 'r4',
      via: RankEarnVia.autoDemote,
      reason: '',
      dpAtChange: 0,
      isRevoked: true,
      earnedAt: null,
    );
    expect(historyTitle(lost, 'THE FORGED'), 'Mất huy hiệu THE FORGED');
  });

  group('enums', () {
    test('PointSource.parse maps wire values and falls back to other', () {
      expect(PointSource.parse('SESSION'), PointSource.session);
      expect(PointSource.parse('ARMORY_REDEEM'), PointSource.armoryRedeem);
      expect(PointSource.parse('???'), PointSource.other);
      expect(PointSource.filterable.contains(PointSource.other), isFalse);
      expect(PointSource.filterable.length, 12);
    });

    test('RankStatus.parse and TrialStatus.parse', () {
      expect(RankStatus.parse('TRIAL_REQUIRED'), RankStatus.trialRequired);
      expect(RankStatus.parse('MAX_RANK'), RankStatus.maxRank);
      expect(RankStatus.parse('???'), RankStatus.inProgress);
      expect(TrialStatus.parse('SCHEDULED'), TrialStatus.scheduled);
      expect(TrialStatus.parse(null), isNull);
    });

    test('MonthlyPointStatus clamps fractions and detects the cap', () {
      const s = MonthlyPointStatus(dpUsed: 1200, dpCap: 1000, marksUsed: 10, marksCap: 0);
      expect(s.dpFraction, 1);
      expect(s.dpCapReached, isTrue);
      expect(s.marksFraction, 0);
      expect(s.marksCapReached, isFalse);
    });
  });
}
