import { describe, expect, it } from 'vitest';
import {
  addDays,
  addMonthsToDate,
  daysBetween,
  isoWeekdayOf,
  localDate,
  monthStartOf,
  monthsBetween,
  startOfLocalDay,
  weekStartOf,
  zonedToUtc,
} from '../../src/common/utils/time';

const TZ = 'Asia/Ho_Chi_Minh';

describe('time utils', () => {
  it('converts an instant to the local calendar date', () => {
    expect(localDate(new Date('2026-09-30T18:00:00Z'), TZ)).toBe('2026-10-01');
    expect(localDate(new Date('2026-09-30T16:59:00Z'), TZ)).toBe('2026-09-30');
  });
  it('converts local wall time back to UTC', () => {
    expect(zonedToUtc('2026-10-04', '18:30', TZ).toISOString()).toBe('2026-10-04T11:30:00.000Z');
    expect(startOfLocalDay('2026-10-04', TZ).toISOString()).toBe('2026-10-03T17:00:00.000Z');
  });
  it('does calendar arithmetic on date strings', () => {
    expect(addDays('2026-10-30', 3)).toBe('2026-11-02');
    expect(addMonthsToDate('2026-01-31', 1)).toMatch(/^2026-0(2-28|3-0[1-3])$/);
    expect(daysBetween('2026-10-01', '2026-10-15')).toBe(14);
  });
  it('finds ISO weekdays, week and month starts', () => {
    expect(isoWeekdayOf('2026-10-04')).toBe(7); // Sunday
    expect(weekStartOf('2026-10-04')).toBe('2026-09-28'); // Monday
    expect(monthStartOf('2026-10-17')).toBe('2026-10-01');
  });
  it('measures fractional months with a 30.44-day month', () => {
    const from = new Date('2026-01-01T00:00:00Z');
    expect(monthsBetween(from, new Date(from.getTime() + 30.44 * 86_400_000))).toBeCloseTo(1, 5);
  });
});
