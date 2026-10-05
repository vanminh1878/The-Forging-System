import { env } from '../../config/env';

/*
 * Timezone-aware helpers. Business rules ("today", "this week", "this month")
 * are always evaluated in the tenant's timezone (APP_TIMEZONE), never in the
 * server's local zone. Weeks run Monday..Sunday.
 */

const MS_PER_DAY = 86_400_000;

export interface ZonedParts {
  year: number;
  month: number; // 1..12
  day: number;
  hour: number;
  minute: number;
  second: number;
  isoWeekday: number; // 1 = Monday .. 7 = Sunday
}

const formatterCache = new Map<string, Intl.DateTimeFormat>();

function formatter(tz: string): Intl.DateTimeFormat {
  let f = formatterCache.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      weekday: 'short',
    });
    formatterCache.set(tz, f);
  }
  return f;
}

const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

export function zonedParts(date: Date, tz: string = env.APP_TIMEZONE): ZonedParts {
  const map: Record<string, string> = {};
  for (const p of formatter(tz).formatToParts(date)) map[p.type] = p.value;
  return {
    year: Number(map.year),
    month: Number(map.month),
    day: Number(map.day),
    hour: Number(map.hour),
    minute: Number(map.minute),
    second: Number(map.second),
    isoWeekday: WEEKDAYS[map.weekday] ?? 1,
  };
}

const pad2 = (n: number) => String(n).padStart(2, '0');

/** 'YYYY-MM-DD' of the instant in the given timezone. */
export function localDate(date: Date, tz: string = env.APP_TIMEZONE): string {
  const p = zonedParts(date, tz);
  return `${p.year}-${pad2(p.month)}-${pad2(p.day)}`;
}

/** Adds whole days to a 'YYYY-MM-DD' string (calendar arithmetic, DST safe). */
export function addDays(dateStr: string, days: number): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  const t = Date.UTC(y, m - 1, d) + days * MS_PER_DAY;
  const r = new Date(t);
  return `${r.getUTCFullYear()}-${pad2(r.getUTCMonth() + 1)}-${pad2(r.getUTCDate())}`;
}

export function addMonthsToDate(dateStr: string, months: number): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  const target = new Date(Date.UTC(y, m - 1 + months, 1));
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  return `${target.getUTCFullYear()}-${pad2(target.getUTCMonth() + 1)}-${pad2(Math.min(d, lastDay))}`;
}

export function daysBetween(fromStr: string, toStr: string): number {
  const [y1, m1, d1] = fromStr.split('-').map(Number);
  const [y2, m2, d2] = toStr.split('-').map(Number);
  return Math.round((Date.UTC(y2, m2 - 1, d2) - Date.UTC(y1, m1 - 1, d1)) / MS_PER_DAY);
}

/** ISO weekday (1 = Monday .. 7 = Sunday) of a 'YYYY-MM-DD' string. */
export function isoWeekdayOf(dateStr: string): number {
  const [y, m, d] = dateStr.split('-').map(Number);
  const w = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return w === 0 ? 7 : w;
}

/** Monday of the week containing the given local date. */
export function weekStartOf(dateStr: string): string {
  return addDays(dateStr, -(isoWeekdayOf(dateStr) - 1));
}

export function monthStartOf(dateStr: string): string {
  return `${dateStr.slice(0, 7)}-01`;
}

/**
 * Converts a local wall-clock time in `tz` to the matching UTC instant.
 * Works by correcting a UTC guess with the zone's offset at that moment.
 */
export function zonedToUtc(dateStr: string, timeStr: string, tz: string = env.APP_TIMEZONE): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  const [hh, mm] = timeStr.split(':').map(Number);
  const guess = Date.UTC(y, m - 1, d, hh, mm, 0);
  const p = zonedParts(new Date(guess), tz);
  const asIfUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return new Date(guess - (asIfUtc - guess));
}

/** UTC instant of local midnight for the given local date. */
export function startOfLocalDay(dateStr: string, tz: string = env.APP_TIMEZONE): Date {
  return zonedToUtc(dateStr, '00:00', tz);
}

/** Fractional months between two instants (30.44-day month, as used by the rank time-gate). */
export function monthsBetween(from: Date, to: Date): number {
  return (to.getTime() - from.getTime()) / (MS_PER_DAY * 30.44);
}
