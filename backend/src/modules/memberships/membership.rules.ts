import { daysBetween } from '../../common/utils/time';

export type RenewNotice = 'NO_PACKAGE' | 'ENDED' | 'ENDING_SOON' | 'OK';

export interface MembershipUsage {
  /** null = unlimited sessions. */
  sessionsRemaining: number | null;
  /** Calendar days left in the tenant timezone (0 = last day); null = no end date. */
  daysRemaining: number | null;
}

export function usageOf(
  m: { totalSessions: number | null; usedSessions: number; endDate: string | null },
  today: string,
): MembershipUsage {
  return {
    sessionsRemaining: m.totalSessions === null ? null : Math.max(0, m.totalSessions - m.usedSessions),
    daysRemaining: m.endDate === null ? null : daysBetween(today, m.endDate),
  };
}

/** An ACTIVE row can still be stale until the expiry job runs: it is valid only with days and sessions left. */
export function isValid(u: MembershipUsage): boolean {
  return (
    (u.daysRemaining === null || u.daysRemaining >= 0) &&
    (u.sessionsRemaining === null || u.sessionsRemaining > 0)
  );
}

/** Whether an ACTIVE package can be charged for a session on `onDate` (YYYY-MM-DD, compared as strings). */
export function isUsableOn(
  m: { startDate: string; endDate: string | null; totalSessions: number | null; usedSessions: number },
  onDate: string,
): boolean {
  return (
    m.startDate <= onDate &&
    (m.endDate === null || m.endDate >= onDate) &&
    (m.totalSessions === null || m.usedSessions < m.totalSessions)
  );
}

export function isEndingSoon(u: MembershipUsage, remindDays: number, remindSessions: number): boolean {
  return (
    (u.daysRemaining !== null && u.daysRemaining <= remindDays) ||
    (u.sessionsRemaining !== null && u.sessionsRemaining <= remindSessions)
  );
}

export function renewNoticeOf(input: {
  current: MembershipUsage | null;
  hasScheduled: boolean;
  hasEnded: boolean;
  endingSoon: boolean;
}): RenewNotice {
  if (!input.current) return input.hasEnded ? 'ENDED' : 'NO_PACKAGE';
  if (!isValid(input.current)) return 'ENDED';
  // A queued follow-on package means the member already renewed.
  return input.endingSoon && !input.hasScheduled ? 'ENDING_SOON' : 'OK';
}
