import { describe, expect, it } from 'vitest';
import { applyMonthlyCap, isCapped, marksForSession } from '../../src/modules/points/points.rules';

const base = { usedDpThisMonth: 0, usedMarksThisMonth: 0, dpCap: 1200, marksCap: 150 };

describe('applyMonthlyCap', () => {
  it('passes uncapped sources through untouched', () => {
    const r = applyMonthlyCap({ ...base, source: 'RANK_TRIAL', dp: 5000, marks: 900, usedDpThisMonth: 1200 });
    expect(r).toEqual({ dp: 5000, marks: 900, capped: false });
  });

  it('grants the full amount while under the cap', () => {
    expect(applyMonthlyCap({ ...base, source: 'SESSION', dp: 50, marks: 17 })).toEqual({ dp: 50, marks: 17, capped: false });
  });

  it('trims to the remaining room', () => {
    const r = applyMonthlyCap({ ...base, source: 'CHALLENGE', dp: 200, marks: 10, usedDpThisMonth: 1100 });
    expect(r).toEqual({ dp: 100, marks: 10, capped: true });
  });

  it('caps each currency independently', () => {
    const r = applyMonthlyCap({ ...base, source: 'ACADEMY', dp: 70, marks: 25, usedMarksThisMonth: 140 });
    expect(r).toEqual({ dp: 70, marks: 10, capped: true });
  });

  it('awards nothing once the cap is exhausted', () => {
    const r = applyMonthlyCap({ ...base, source: 'ATTITUDE', dp: 10, marks: 5, usedDpThisMonth: 1300, usedMarksThisMonth: 150 });
    expect(r).toEqual({ dp: 0, marks: 0, capped: true });
  });
});

describe('isCapped / marksForSession', () => {
  it('knows which sources count toward the cap', () => {
    for (const s of ['SESSION', 'ATTITUDE', 'ACADEMY', 'CHALLENGE', 'COMEBACK']) expect(isCapped(s)).toBe(true);
    for (const s of ['RANK_TRIAL', 'EARLY_RENEWAL', 'MANUAL_ADJUSTMENT', 'REVERSAL', 'ARMORY_REDEEM', 'OPENING']) {
      expect(isCapped(s)).toBe(false);
    }
  });
  it('derives marks from DP with a safe divisor', () => {
    expect(marksForSession(50, 3)).toBe(17);
    expect(marksForSession(50, 0)).toBe(50);
  });
});
