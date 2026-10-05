import { monthsBetween } from '../../common/utils/time';

/**
 * Pure rank logic (no I/O), mirroring the customer-approved flow:
 *  - promotion needs DP + time-gate + course-gate + trial-gate;
 *  - a rank previously reached (peak) never needs a new trial;
 *  - dropping below the current threshold demotes immediately.
 */

export interface RankDef {
  id: string;
  rankOrder: number;
  code: string;
  nameEn: string;
  nameVi: string | null;
  dpThreshold: number;
  minActiveMonths: number;
  requiresTrial: boolean;
  approvalRole: 'COACH' | 'HEAD_COACH' | 'ADMIN' | null;
  isHonorary: boolean;
  requiredCourseIds: string[];
}

export type TrialStatus = 'NOT_REQUESTED' | 'PENDING' | 'SCHEDULED' | 'PASSED' | 'FAILED' | 'CANCELLED';

export interface MemberRankInput {
  currentRankOrder: number;
  peakRankOrder: number;
  dpBalance: number;
  joinedAt: Date;
  completedCourseIds: ReadonlySet<string>;
  /** Status of the member's latest trial request for the NEXT rank, if any. */
  latestTrialStatus: TrialStatus | null;
}

export type RankProgressStatus =
  | 'MAX_RANK'
  | 'IN_PROGRESS' // missing DP, time or course
  | 'RANK_READY' // everything satisfied - promotion happens automatically
  | 'TRIAL_REQUIRED' // all gates but the trial are satisfied
  | 'TRIAL_PENDING'; // trial requested, waiting for the examiner

export interface RankProgress {
  current: RankDef;
  next: RankDef | null;
  status: RankProgressStatus;
  dpOk: boolean;
  timeOk: boolean;
  courseOk: boolean;
  dpRemaining: number;
  monthsIn: number;
  monthsRemaining: number;
  missingCourseIds: string[];
  trialRequired: boolean;
  trialWaived: boolean;
  trialStatus: TrialStatus | null;
}

export function sortRanks(ranks: RankDef[]): RankDef[] {
  return [...ranks].sort((a, b) => a.rankOrder - b.rankOrder);
}

export function rankByOrder(ranks: RankDef[], order: number): RankDef | undefined {
  return ranks.find((r) => r.rankOrder === order);
}

export function computeRankProgress(ranks: RankDef[], member: MemberRankInput, now: Date): RankProgress {
  const current = rankByOrder(ranks, member.currentRankOrder);
  if (!current) throw new Error(`Unknown current rank order ${member.currentRankOrder}`);
  const next = rankByOrder(ranks, member.currentRankOrder + 1) ?? null;

  const monthsIn = monthsBetween(member.joinedAt, now);
  if (!next) {
    return {
      current,
      next: null,
      status: 'MAX_RANK',
      dpOk: true,
      timeOk: true,
      courseOk: true,
      dpRemaining: 0,
      monthsIn,
      monthsRemaining: 0,
      missingCourseIds: [],
      trialRequired: false,
      trialWaived: false,
      trialStatus: null,
    };
  }

  const dpOk = member.dpBalance >= next.dpThreshold;
  const timeOk = monthsIn >= next.minActiveMonths;
  const missingCourseIds = next.requiredCourseIds.filter((c) => !member.completedCourseIds.has(c));
  const courseOk = missingCourseIds.length === 0;
  const trialWaived = next.rankOrder <= member.peakRankOrder; // already reached once: no new trial
  const trialRequired = next.requiresTrial && !trialWaived;
  const trialStatus: TrialStatus | null = trialRequired ? (member.latestTrialStatus ?? 'NOT_REQUESTED') : null;

  let status: RankProgressStatus;
  if (!dpOk || !timeOk || !courseOk) status = 'IN_PROGRESS';
  else if (!trialRequired) status = 'RANK_READY';
  else if (trialStatus === 'NOT_REQUESTED' || trialStatus === 'FAILED' || trialStatus === 'CANCELLED') status = 'TRIAL_REQUIRED';
  else if (trialStatus === 'PENDING' || trialStatus === 'SCHEDULED') status = 'TRIAL_PENDING';
  else status = 'RANK_READY'; // trial PASSED

  return {
    current,
    next,
    status,
    dpOk,
    timeOk,
    courseOk,
    dpRemaining: Math.max(0, next.dpThreshold - member.dpBalance),
    monthsIn,
    monthsRemaining: Math.max(0, next.minActiveMonths - monthsIn),
    missingCourseIds,
    trialRequired,
    trialWaived,
    trialStatus,
  };
}

/**
 * Number of ranks the member must drop so that DP is at or above the threshold
 * of the resulting rank (rank 1 is the floor).
 */
export function demotionTarget(ranks: RankDef[], currentOrder: number, dpBalance: number): number {
  let order = currentOrder;
  while (order > 1) {
    const rank = rankByOrder(ranks, order);
    if (!rank || dpBalance >= rank.dpThreshold) break;
    order -= 1;
  }
  return order;
}

/** Who may decide a trial for a rank. ADMIN can always decide; HEAD_COACH covers COACH ranks. */
export function canDecideTrial(approvalRole: RankDef['approvalRole'], roles: readonly string[]): boolean {
  const required = approvalRole ?? 'COACH';
  const isAdmin = roles.includes('ADMIN') || roles.includes('SUPER_ADMIN');
  if (isAdmin) return true;
  if (required === 'ADMIN') return false;
  if (required === 'HEAD_COACH') return roles.includes('HEAD_COACH');
  return roles.includes('COACH') || roles.includes('HEAD_COACH');
}

/** Admin-approved ranks: coaches may only recommend, not finalise. */
export function coachCanOnlyRecommend(approvalRole: RankDef['approvalRole'], roles: readonly string[]): boolean {
  const isAdmin = roles.includes('ADMIN') || roles.includes('SUPER_ADMIN');
  return !isAdmin && approvalRole === 'ADMIN';
}
