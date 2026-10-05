/**
 * Pure point-calculation rules (no I/O) so they can be unit tested in isolation.
 */

/**
 * Ledger sources that count toward the monthly DP / Marks cap
 * (regular activity). Rank Trial, opening balance, early renewal, manual
 * adjustments, reversals and Armory debits are never capped.
 */
export const CAP_SOURCES = ['SESSION', 'ATTITUDE', 'ACADEMY', 'CHALLENGE', 'COMEBACK'] as const;

export type LedgerSource =
  | 'OPENING'
  | 'SESSION'
  | 'ATTITUDE'
  | 'ACADEMY'
  | 'STREAK_MILESTONE'
  | 'CHALLENGE'
  | 'RANK_TRIAL'
  | 'EARLY_RENEWAL'
  | 'COMEBACK'
  | 'ARMORY_REDEEM'
  | 'MANUAL_ADJUSTMENT'
  | 'REVERSAL';

export function isCapped(source: string): boolean {
  return (CAP_SOURCES as readonly string[]).includes(source);
}

export interface CapInput {
  source: string;
  dp: number;
  marks: number;
  usedDpThisMonth: number;
  usedMarksThisMonth: number;
  dpCap: number;
  marksCap: number;
}

export interface CapResult {
  dp: number;
  marks: number;
  /** True when part of the requested amount was cut by the monthly cap. */
  capped: boolean;
}

/** Trims a requested award so the member never exceeds the monthly cap. */
export function applyMonthlyCap(input: CapInput): CapResult {
  if (!isCapped(input.source)) return { dp: input.dp, marks: input.marks, capped: false };
  const roomDp = Math.max(0, input.dpCap - input.usedDpThisMonth);
  const roomMarks = Math.max(0, input.marksCap - input.usedMarksThisMonth);
  const dp = Math.min(input.dp, roomDp);
  const marks = Math.min(input.marks, roomMarks);
  return { dp, marks, capped: dp < input.dp || marks < input.marks };
}

/** Session Marks derive from the DP of the session (configurable divisor). */
export function marksForSession(dp: number, divisor: number): number {
  return Math.round(dp / Math.max(1, divisor));
}

/** Large or balance-breaking manual adjustments need an explicit confirmation. */
export const MANUAL_ADJUST_CONFIRM_THRESHOLD = 500;
