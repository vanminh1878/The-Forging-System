/**
 * Catalog of every tunable business parameter. The `system_configs` table holds
 * tenant overrides; when a row is missing the default below applies. The admin
 * configuration screens are generated from this list (group, type, description).
 */
export type ConfigGroup =
  | 'POINTS'
  | 'RANK'
  | 'STREAK'
  | 'CHALLENGE'
  | 'ARMORY'
  | 'MEMBERSHIP'
  | 'NOTIFICATION'
  | 'CHECKIN'
  | 'CLASS'
  | 'SECURITY';

export type ConfigValueType = 'INT' | 'DECIMAL' | 'BOOL' | 'TEXT' | 'TIME' | 'JSON';

export interface ConfigDefinition {
  key: string;
  group: ConfigGroup;
  type: ConfigValueType;
  defaultValue: unknown;
  description: string;
  min?: number;
  max?: number;
}

const def = (
  key: string,
  group: ConfigGroup,
  type: ConfigValueType,
  defaultValue: unknown,
  description: string,
  range: { min?: number; max?: number } = {},
): ConfigDefinition => ({ key, group, type, defaultValue, description, ...range });

export const CONFIG_CATALOG: ConfigDefinition[] = [
  // ---- Points ----
  def('points.dp_monthly_cap', 'POINTS', 'INT', 1200, 'Maximum DP per member per month from regular activity', { min: 0 }),
  def('points.marks_monthly_cap', 'POINTS', 'INT', 150, 'Maximum HVP Marks per member per month from regular activity', { min: 0 }),
  def('points.completion_threshold', 'POINTS', 'INT', 70, 'Minimum completion percent for a session to count', { min: 1, max: 100 }),
  def('points.marks_per_dp_divisor', 'POINTS', 'INT', 3, 'Session Marks = round(DP / divisor)', { min: 1 }),
  def('points.attitude_dp', 'POINTS', 'INT', 10, 'DP granted for good attitude (once per member per session)', { min: 0 }),
  def('points.attitude_marks', 'POINTS', 'INT', 5, 'Marks granted for good attitude', { min: 0 }),
  def('points.academy_pass_dp', 'POINTS', 'INT', 70, 'DP for passing an Academy / exam session', { min: 0 }),
  def('points.academy_pass_marks', 'POINTS', 'INT', 25, 'Marks for passing an Academy / exam session', { min: 0 }),
  def('points.coach_attitude_limit_per_day', 'POINTS', 'INT', 12, 'Attitude grants a coach may give per day', { min: 0 }),
  def('points.coach_attitude_limit_per_month', 'POINTS', 'INT', 120, 'Attitude grants a coach may give per month', { min: 0 }),
  def('points.rank_trial_bonus_dp', 'POINTS', 'INT', 150, 'DP bonus when a Rank Trial is passed', { min: 0 }),
  def('points.rank_trial_bonus_marks', 'POINTS', 'INT', 40, 'Marks bonus when a Rank Trial is passed', { min: 0 }),
  def('points.early_renewal_marks', 'POINTS', 'INT', 50, 'Marks bonus for renewing early (once per membership)', { min: 0 }),
  def('points.comeback_dp', 'POINTS', 'INT', 50, 'DP bonus for coming back after a long absence', { min: 0 }),
  def('points.comeback_gap_days', 'POINTS', 'INT', 14, 'Absence length (days) that triggers the comeback bonus', { min: 1 }),

  // ---- Rank ----
  def('rank.demotion_enabled', 'RANK', 'BOOL', true, 'Demote automatically when DP falls below the current rank threshold'),

  // ---- Streak ----
  def('streak.weekly_min_sessions', 'STREAK', 'INT', 3, 'Valid sessions needed per week to keep the streak', { min: 1, max: 14 }),
  def('streak.freeze_every_weeks', 'STREAK', 'INT', 4, 'One Streak Freeze is granted every N streak weeks', { min: 1 }),
  def('streak.max_freeze_per_month', 'STREAK', 'INT', 2, 'Maximum Streak Freezes that may be used per month', { min: 0 }),
  def('streak.milestones', 'STREAK', 'JSON', { '4': 20, '8': 40, '12': 80 }, 'Milestone bonus DP keyed by streak week'),

  // ---- Challenge ----
  def('challenge.monthly_reward_limit', 'CHALLENGE', 'INT', 2, 'Rewarded challenges per member per month', { min: 0 }),
  def('challenge.nudge_hours_before_end', 'CHALLENGE', 'INT', 24, 'Remind learners with unfinished challenges this many hours before the deadline', { min: 1 }),

  // ---- Membership / account lifecycle ----
  def('membership.inactive_months', 'MEMBERSHIP', 'INT', 12, 'Months without activity (and no package) before INACTIVE', { min: 1 }),
  def('membership.inactive_warn_days', 'MEMBERSHIP', 'INT', 30, 'Warn this many days before an account turns INACTIVE', { min: 0 }),
  def('membership.remind_days', 'MEMBERSHIP', 'INT', 7, 'Send renewal reminder when this many days remain', { min: 0 }),
  def('membership.remind_sessions', 'MEMBERSHIP', 'INT', 2, 'Send renewal reminder when this many sessions remain', { min: 0 }),

  // ---- Armory ----
  def('armory.pending_pickup_expiry_days', 'ARMORY', 'INT', 14, 'Days after which an unclaimed redemption expires', { min: 1 }),
  def('armory.low_stock_threshold', 'ARMORY', 'INT', 3, 'Stock at or below this number is flagged as low in the inventory screen', { min: 0 }),

  // ---- Classes ----
  def('classes.session_horizon_days', 'CLASS', 'INT', 28, 'Sessions are generated from class schedules this many days ahead', { min: 7, max: 90 }),

  // ---- Check-in ----
  def('checkin.code_ttl_seconds', 'CHECKIN', 'INT', 60, 'Lifetime of a rotating branch check-in code', { min: 10 }),
  def('checkin.opens_before_minutes', 'CHECKIN', 'INT', 45, 'Check-in opens this many minutes before a session starts', { min: 0 }),
  def('checkin.closes_after_minutes', 'CHECKIN', 'INT', 30, 'Check-in stays open this many minutes after a session starts', { min: 0 }),
  def('checkin.geofence_enabled', 'CHECKIN', 'BOOL', false, 'Reject check-ins made outside the branch geofence'),

  // ---- Security ----
  def('security.password_min_length', 'SECURITY', 'INT', 8, 'Minimum password length', { min: 6 }),
  def('security.pin_ttl_minutes', 'SECURITY', 'INT', 5, 'Password reset PIN lifetime', { min: 1 }),
  def('security.pin_max_attempts', 'SECURITY', 'INT', 5, 'Wrong PIN attempts allowed', { min: 1 }),
];

export const CONFIG_BY_KEY: ReadonlyMap<string, ConfigDefinition> = new Map(
  CONFIG_CATALOG.map((d) => [d.key, d]),
);
