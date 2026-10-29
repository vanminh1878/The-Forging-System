import { describe, expect, it } from 'vitest';
import { isEndingSoon, renewNoticeOf, usageOf } from '../../src/modules/memberships/membership.rules';

describe('membership rules', () => {
  const m = { totalSessions: 36, usedSessions: 30, endDate: '2026-10-31' };

  it('computes remaining sessions and calendar days', () => {
    expect(usageOf(m, '2026-10-24')).toEqual({ sessionsRemaining: 6, daysRemaining: 7 });
    expect(usageOf(m, '2026-10-31').daysRemaining).toBe(0);
    expect(usageOf({ totalSessions: null, usedSessions: 5, endDate: null }, '2026-10-24')).toEqual({ sessionsRemaining: null, daysRemaining: null });
  });

  it('flags ending soon at the thresholds (inclusive)', () => {
    expect(isEndingSoon({ sessionsRemaining: 10, daysRemaining: 7 }, 7, 2)).toBe(true);
    expect(isEndingSoon({ sessionsRemaining: 10, daysRemaining: 8 }, 7, 2)).toBe(false);
    expect(isEndingSoon({ sessionsRemaining: 2, daysRemaining: 30 }, 7, 2)).toBe(true);
    expect(isEndingSoon({ sessionsRemaining: 3, daysRemaining: null }, 7, 2)).toBe(false);
  });

  it('derives the notice', () => {
    const ok = { sessionsRemaining: 10, daysRemaining: 30 };
    expect(renewNoticeOf({ current: null, hasScheduled: false, hasEnded: false, endingSoon: false })).toBe('NO_PACKAGE');
    expect(renewNoticeOf({ current: null, hasScheduled: false, hasEnded: true, endingSoon: false })).toBe('ENDED');
    expect(renewNoticeOf({ current: { sessionsRemaining: 0, daysRemaining: 5 }, hasScheduled: false, hasEnded: false, endingSoon: true })).toBe('ENDED');
    expect(renewNoticeOf({ current: { sessionsRemaining: 5, daysRemaining: -1 }, hasScheduled: false, hasEnded: false, endingSoon: true })).toBe('ENDED');
    expect(renewNoticeOf({ current: ok, hasScheduled: false, hasEnded: false, endingSoon: true })).toBe('ENDING_SOON');
    expect(renewNoticeOf({ current: ok, hasScheduled: true, hasEnded: false, endingSoon: true })).toBe('OK');
    expect(renewNoticeOf({ current: ok, hasScheduled: false, hasEnded: false, endingSoon: false })).toBe('OK');
  });
});
