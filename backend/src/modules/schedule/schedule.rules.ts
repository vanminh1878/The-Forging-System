/** Pure rules for the learner schedule (CLS-04). */

export type ScheduleStatus =
  'UPCOMING' | 'AWAITING_COACH' | 'CONFIRMED_PASS' | 'CONFIRMED_FAIL' | 'ABSENT' | 'CANCELLED';

export const SCHEDULE_STATUSES: readonly ScheduleStatus[] = [
  'UPCOMING',
  'AWAITING_COACH',
  'CONFIRMED_PASS',
  'CONFIRMED_FAIL',
  'ABSENT',
  'CANCELLED',
];

/** Priority: cancelled session > the learner's own attendance > a missed (ended) session > upcoming. */
export function deriveStatus(
  session: { status: string; endsAt: Date },
  attendanceStatus: string | null,
  now: Date,
): ScheduleStatus {
  if (session.status === 'CANCELLED') return 'CANCELLED';
  if (attendanceStatus) return attendanceStatus as ScheduleStatus;
  return session.endsAt.getTime() < now.getTime() ? 'ABSENT' : 'UPCOMING';
}
