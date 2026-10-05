import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/features/fighter_record/data/dto/points_dto.dart';
import 'package:hvp_forging/features/fighter_record/data/dto/rank_dto.dart';
import 'package:hvp_forging/features/fighter_record/domain/badge_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/rank_models.dart';

Map<String, dynamic> _rankJson(int order, {String code = 'THE_FORGED', int dp = 3000}) => <String, dynamic>{
      'id': 'r$order',
      'rankOrder': order,
      'code': code,
      'nameEn': code.replaceAll('_', ' '),
      'nameVi': null,
      'dpThreshold': dp,
      'minActiveMonths': 6,
      'requiresTrial': true,
      'approvalRole': 'COACH',
      'isHonorary': false,
      'requiredCourseIds': <String>['c1'],
    };

void main() {
  test('GET /me/rank payload', () {
    final progress = rankProgressFromJson(<String, dynamic>{
      'current': _rankJson(3, code: 'THE_DISCIPLINED', dp: 1500),
      'next': _rankJson(4),
      'status': 'TRIAL_REQUIRED',
      'dpOk': true,
      'timeOk': true,
      'courseOk': true,
      'dpRemaining': 0,
      'monthsIn': 7.25,
      'monthsRemaining': 0,
      'missingCourseIds': <String>[],
      'trialRequired': true,
      'trialWaived': false,
      'trialStatus': 'NOT_REQUESTED',
      'missingCourses': <dynamic>[],
      'peakRankOrder': 3,
    });
    expect(progress.current.order, 3);
    expect(progress.current.displayName, 'THE DISCIPLINED');
    expect(progress.next!.order, 4);
    expect(progress.next!.requiresTrial, isTrue);
    expect(progress.status, RankStatus.trialRequired);
    expect(progress.monthsIn, 7.25);
    expect(progress.trialStatus, TrialStatus.notRequested);
    expect(progress.isMaxRank, isFalse);
  });

  test('max rank has no next and no trial status', () {
    final progress = rankProgressFromJson(<String, dynamic>{
      'current': _rankJson(7, code: 'THE_LEGACY', dp: 20000),
      'next': null,
      'status': 'MAX_RANK',
      'dpOk': true,
      'timeOk': true,
      'courseOk': true,
      'dpRemaining': 0,
      'monthsIn': 30,
      'monthsRemaining': 0,
      'trialRequired': false,
      'trialWaived': false,
      'trialStatus': null,
      'peakRankOrder': 7,
    });
    expect(progress.isMaxRank, isTrue);
    expect(progress.status, RankStatus.maxRank);
    expect(progress.trialStatus, isNull);
    expect(progress.missingCourses, isEmpty);
  });

  test('missing courses carry their names', () {
    final progress = rankProgressFromJson(<String, dynamic>{
      'current': _rankJson(3),
      'next': _rankJson(4),
      'status': 'IN_PROGRESS',
      'courseOk': false,
      'missingCourses': <dynamic>[
        <String, dynamic>{'id': 'c1', 'name': 'Boxing nền tảng'},
      ],
    });
    expect(progress.missingCourses.single.name, 'Boxing nền tảng');
    expect(progress.courseOk, isFalse);
  });

  test('GET /me/badges row is keyed by toRankId', () {
    final badge = earnedBadgeFromJson(<String, dynamic>{
      'id': 'h1',
      'toRankId': 'r2',
      'rankOrder': 2,
      'nameEn': 'THE INITIATED',
      'earnedAt': '2026-03-01T03:00:00.000Z',
      'reason': 'Đạt 500 DP',
      'isRevoked': false,
    });
    expect(badge.rankId, 'r2');
    expect(badge.rankOrder, 2);
    expect(badge.earnedAt, isNotNull);
  });

  test('GET /me/rank-history row', () {
    final entry = rankHistoryFromJson(<String, dynamic>{
      'id': 'h2',
      'fromRankId': 'r3',
      'toRankId': 'r3',
      'earnedVia': 'AUTO_DEMOTE',
      'reason': 'DP thấp hơn ngưỡng',
      'dpAtChange': '1400',
      'isRevoked': true,
      'earnedAt': '2026-06-01T00:00:00.000Z',
    });
    expect(entry.via, RankEarnVia.autoDemote);
    expect(entry.isRevoked, isTrue);
    expect(entry.dpAtChange, 1400);
  });

  test('ledger page uses meta.totalPages for hasMore', () {
    final page = pointsPageFromEnvelope(
      const ApiEnvelope(
        data: <dynamic>[
          <String, dynamic>{
            'id': 't1',
            'source': 'SESSION',
            'dpAmount': 50,
            'marksAmount': '10',
            'isCapped': true,
            'note': null,
            'occurredAt': '2026-10-01T10:00:00.000Z',
          },
        ],
        meta: <String, dynamic>{'page': 1, 'limit': 20, 'total': 45, 'totalPages': 3},
      ),
    );
    expect(page.items.single.source, PointSource.session);
    expect(page.items.single.marksAmount, 10);
    expect(page.items.single.isCapped, isTrue);
    expect(page.total, 45);
    expect(page.hasMore, isTrue);
  });

  test('last page has no more', () {
    final page = pointsPageFromEnvelope(
      const ApiEnvelope(data: <dynamic>[], meta: <String, dynamic>{'page': 3, 'limit': 20, 'total': 45, 'totalPages': 3}),
    );
    expect(page.hasMore, isFalse);
  });

  test('GET /me/points/monthly', () {
    final status = monthlyStatusFromJson(<String, dynamic>{'dpUsed': 300, 'dpCap': 1000, 'marksUsed': 20, 'marksCap': 100});
    expect(status.dpFraction, 0.3);
    expect(status.marksFraction, 0.2);
  });
}
