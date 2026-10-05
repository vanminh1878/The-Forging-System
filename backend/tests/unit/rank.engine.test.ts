import { describe, expect, it } from 'vitest';
import {
  canDecideTrial,
  coachCanOnlyRecommend,
  computeRankProgress,
  demotionTarget,
  type MemberRankInput,
  type RankDef,
} from '../../src/modules/ranks/rank.engine';

const rank = (order: number, dp: number, months: number, over: Partial<RankDef> = {}): RankDef => ({
  id: `r${order}`,
  rankOrder: order,
  code: `R${order}`,
  nameEn: `Rank ${order}`,
  nameVi: null,
  dpThreshold: dp,
  minActiveMonths: months,
  requiresTrial: false,
  approvalRole: null,
  isHonorary: false,
  requiredCourseIds: [],
  ...over,
});

const RANKS: RankDef[] = [
  rank(1, 0, 0),
  rank(2, 500, 1),
  rank(3, 2500, 3, { requiresTrial: true, requiredCourseIds: ['c1'] }),
  rank(4, 5000, 6, { requiresTrial: true, approvalRole: 'ADMIN' }),
];

const NOW = new Date('2026-10-01T00:00:00Z');
const monthsAgo = (m: number) => new Date(NOW.getTime() - m * 30.44 * 86_400_000 - 1000);

const member = (over: Partial<MemberRankInput> = {}): MemberRankInput => ({
  currentRankOrder: 1,
  peakRankOrder: 1,
  dpBalance: 0,
  joinedAt: monthsAgo(0),
  completedCourseIds: new Set(),
  latestTrialStatus: null,
  ...over,
});

describe('computeRankProgress', () => {
  it('reports IN_PROGRESS with the remaining DP and time', () => {
    const p = computeRankProgress(RANKS, member({ dpBalance: 200, joinedAt: monthsAgo(0.5) }), NOW);
    expect(p.status).toBe('IN_PROGRESS');
    expect(p.dpRemaining).toBe(300);
    expect(p.dpOk).toBe(false);
    expect(p.timeOk).toBe(false);
  });

  it('is RANK_READY when DP and time are met and no trial is needed', () => {
    const p = computeRankProgress(RANKS, member({ dpBalance: 500, joinedAt: monthsAgo(1) }), NOW);
    expect(p.status).toBe('RANK_READY');
  });

  it('keeps DP alone from promoting when the time gate is unmet', () => {
    const p = computeRankProgress(RANKS, member({ dpBalance: 9999, joinedAt: monthsAgo(0.2) }), NOW);
    expect(p.dpOk).toBe(true);
    expect(p.timeOk).toBe(false);
    expect(p.status).toBe('IN_PROGRESS');
  });

  it('lists missing courses and blocks promotion until they are completed', () => {
    const base = { currentRankOrder: 2, peakRankOrder: 2, dpBalance: 3000, joinedAt: monthsAgo(4) };
    const blocked = computeRankProgress(RANKS, member(base), NOW);
    expect(blocked.courseOk).toBe(false);
    expect(blocked.missingCourseIds).toEqual(['c1']);
    expect(blocked.status).toBe('IN_PROGRESS');

    const done = computeRankProgress(RANKS, member({ ...base, completedCourseIds: new Set(['c1']) }), NOW);
    expect(done.status).toBe('TRIAL_REQUIRED');
  });

  it('walks through the trial states', () => {
    const base = { currentRankOrder: 2, peakRankOrder: 2, dpBalance: 3000, joinedAt: monthsAgo(4), completedCourseIds: new Set(['c1']) };
    expect(computeRankProgress(RANKS, member(base), NOW).status).toBe('TRIAL_REQUIRED');
    expect(computeRankProgress(RANKS, member({ ...base, latestTrialStatus: 'PENDING' }), NOW).status).toBe('TRIAL_PENDING');
    expect(computeRankProgress(RANKS, member({ ...base, latestTrialStatus: 'FAILED' }), NOW).status).toBe('TRIAL_REQUIRED');
    expect(computeRankProgress(RANKS, member({ ...base, latestTrialStatus: 'PASSED' }), NOW).status).toBe('RANK_READY');
  });

  it('waives the trial for a rank already reached before (restoration)', () => {
    const p = computeRankProgress(
      RANKS,
      member({ currentRankOrder: 2, peakRankOrder: 3, dpBalance: 3000, joinedAt: monthsAgo(4), completedCourseIds: new Set(['c1']) }),
      NOW,
    );
    expect(p.trialWaived).toBe(true);
    expect(p.status).toBe('RANK_READY');
  });

  it('reports MAX_RANK at the top', () => {
    const p = computeRankProgress(RANKS, member({ currentRankOrder: 4, peakRankOrder: 4, dpBalance: 99999 }), NOW);
    expect(p.status).toBe('MAX_RANK');
    expect(p.next).toBeNull();
  });
});

describe('demotionTarget', () => {
  it('stays when DP still covers the current threshold', () => {
    expect(demotionTarget(RANKS, 3, 2500)).toBe(3);
  });
  it('drops one rank when DP falls under the threshold', () => {
    expect(demotionTarget(RANKS, 3, 2400)).toBe(2);
  });
  it('can drop several ranks at once but never below rank 1', () => {
    expect(demotionTarget(RANKS, 4, 100)).toBe(1);
    expect(demotionTarget(RANKS, 4, 0)).toBe(1);
  });
});

describe('trial authority', () => {
  it('lets any coach decide COACH-approved ranks', () => {
    expect(canDecideTrial('COACH', ['COACH'])).toBe(true);
    expect(canDecideTrial(null, ['COACH'])).toBe(true);
    expect(canDecideTrial('COACH', ['RECEPTIONIST'])).toBe(false);
  });
  it('requires HEAD_COACH or admin for HEAD_COACH ranks', () => {
    expect(canDecideTrial('HEAD_COACH', ['COACH'])).toBe(false);
    expect(canDecideTrial('HEAD_COACH', ['HEAD_COACH'])).toBe(true);
    expect(canDecideTrial('HEAD_COACH', ['ADMIN'])).toBe(true);
  });
  it('requires an admin to finalise ADMIN ranks; coaches only recommend', () => {
    expect(canDecideTrial('ADMIN', ['HEAD_COACH'])).toBe(false);
    expect(canDecideTrial('ADMIN', ['ADMIN'])).toBe(true);
    expect(coachCanOnlyRecommend('ADMIN', ['COACH'])).toBe(true);
    expect(coachCanOnlyRecommend('ADMIN', ['ADMIN'])).toBe(false);
    expect(coachCanOnlyRecommend('COACH', ['COACH'])).toBe(false);
  });
});
