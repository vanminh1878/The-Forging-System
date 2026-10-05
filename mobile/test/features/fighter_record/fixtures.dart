import 'package:hvp_forging/features/fighter_record/domain/badge_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/fighter_record_repository.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';
import 'package:hvp_forging/features/fighter_record/domain/rank_models.dart';

/// The 7 ranks with the real thresholds' shape (values are test data).
List<RankInfo> sampleRanks() => const <RankInfo>[
      RankInfo(id: 'r1', order: 1, code: 'THE_UNKNOWN', nameEn: 'THE UNKNOWN', nameVi: 'Vô danh', dpThreshold: 0, minActiveMonths: 0),
      RankInfo(id: 'r2', order: 2, code: 'THE_INITIATED', nameEn: 'THE INITIATED', nameVi: 'Nhập môn', dpThreshold: 500, minActiveMonths: 1),
      RankInfo(id: 'r3', order: 3, code: 'THE_DISCIPLINED', nameEn: 'THE DISCIPLINED', dpThreshold: 1500, minActiveMonths: 3),
      RankInfo(id: 'r4', order: 4, code: 'THE_FORGED', nameEn: 'THE FORGED', dpThreshold: 3000, minActiveMonths: 6, requiresTrial: true),
      RankInfo(id: 'r5', order: 5, code: 'THE_FIGHTER', nameEn: 'THE FIGHTER', dpThreshold: 6000, minActiveMonths: 9, requiresTrial: true),
      RankInfo(id: 'r6', order: 6, code: 'THE_UNBROKEN', nameEn: 'THE UNBROKEN', dpThreshold: 10000, minActiveMonths: 12, requiresTrial: true),
      RankInfo(id: 'r7', order: 7, code: 'THE_LEGACY', nameEn: 'THE LEGACY', dpThreshold: 20000, minActiveMonths: 24, requiresTrial: true, isHonorary: true),
    ];

RankInfo rankOf(int order) => sampleRanks()[order - 1];

/// Progress of a member at rank 3 working towards rank 4.
RankProgress sampleProgress({
  RankStatus status = RankStatus.inProgress,
  int currentOrder = 3,
  bool withNext = true,
  bool dpOk = false,
  bool timeOk = true,
  bool courseOk = true,
  int dpRemaining = 400,
  bool trialRequired = true,
  TrialStatus? trialStatus,
  List<MissingCourse> missingCourses = const <MissingCourse>[],
  int peakRankOrder = 3,
}) {
  return RankProgress(
    current: rankOf(currentOrder),
    next: withNext ? rankOf(currentOrder + 1) : null,
    status: status,
    dpOk: dpOk,
    timeOk: timeOk,
    courseOk: courseOk,
    dpRemaining: dpRemaining,
    monthsIn: 4.5,
    monthsRemaining: timeOk ? 0 : 1.5,
    trialRequired: trialRequired,
    trialWaived: false,
    trialStatus: trialStatus,
    missingCourses: missingCourses,
    peakRankOrder: peakRankOrder,
  );
}

PointTransaction sampleTx(int n, {PointSource source = PointSource.session, int dp = 50, int marks = 10}) =>
    PointTransaction(
      id: 'tx$n',
      source: source,
      dpAmount: dp,
      marksAmount: marks,
      isCapped: false,
      occurredAt: DateTime.utc(2026, 10, 1, 10, n),
      note: 'Buổi tập số $n',
    );

/// Programmable [FighterRecordRepository]: every endpoint is a settable callback.
class FakeFighterRecordRepository implements FighterRecordRepository {
  Future<RankProgress> Function() onProgress = () async => sampleProgress();
  Future<List<RankInfo>> Function() onRanks = () async => sampleRanks();
  Future<List<EarnedBadge>> Function() onBadges = () async => const <EarnedBadge>[];
  Future<List<RankHistoryEntry>> Function() onHistory = () async => const <RankHistoryEntry>[];
  Future<PointsPage> Function(int page, PointSource? source) onTransactions =
      (page, source) async => const PointsPage(items: <PointTransaction>[], page: 1, totalPages: 1, total: 0);
  Future<MonthlyPointStatus> Function() onMonthly = () async =>
      const MonthlyPointStatus(dpUsed: 300, dpCap: 1000, marksUsed: 20, marksCap: 100);
  Future<void> Function() onRequestTrial = () async {};

  int progressCalls = 0;
  int trialRequests = 0;
  final List<int> transactionPages = <int>[];
  final List<PointSource?> transactionFilters = <PointSource?>[];

  @override
  Future<RankProgress> getProgress() {
    progressCalls++;
    return onProgress();
  }

  @override
  Future<List<RankInfo>> getRanks() => onRanks();

  @override
  Future<List<EarnedBadge>> getBadges() => onBadges();

  @override
  Future<List<RankHistoryEntry>> getHistory() => onHistory();

  @override
  Future<PointsPage> getTransactions({int page = 1, int limit = 20, PointSource? source}) {
    transactionPages.add(page);
    transactionFilters.add(source);
    return onTransactions(page, source);
  }

  @override
  Future<MonthlyPointStatus> getMonthlyStatus() => onMonthly();

  @override
  Future<void> requestRankTrial() {
    trialRequests++;
    return onRequestTrial();
  }
}
