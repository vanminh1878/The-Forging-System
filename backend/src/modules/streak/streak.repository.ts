import { db } from '../../db/database';
import { sql } from '../../db/sql';

export type StreakResult = 'INCREASED' | 'FROZEN' | 'RESET' | 'SKIPPED';

export interface StreakMember {
  id: string;
  currentStreakWeeks: number;
  longestStreakWeeks: number;
  streakStartedWeek: string | null;
}

export interface StreakLog {
  weekStart: string;
  sessionsCount: number;
  targetSessions: number;
  result: StreakResult;
  streakBefore: number;
  streakAfter: number;
  freezeGrantId: string | null;
  createdAt: Date;
}

export class StreakRepository {
  async activeMemberIdsForWeek(start: Date, end: Date): Promise<string[]> {
    const rows = await sql.many<{ id: string }>(
      `SELECT m.user_id AS id FROM members m
       WHERE m.status='ACTIVE' AND (
         m.current_streak_weeks > 0 OR EXISTS (
           SELECT 1 FROM attendances a JOIN sessions s ON s.id=a.session_id AND s.tenant_id=a.tenant_id
           WHERE a.member_id=m.user_id AND a.attendance_status='CONFIRMED_PASS'
             AND s.starts_at >= $1 AND s.starts_at < $2
         )
       )`,
      [start, end],
    );
    return rows.map((row) => row.id);
  }

  member(id: string, lock = false): Promise<StreakMember | null> {
    return sql.one<StreakMember>(
      `SELECT user_id AS id,current_streak_weeks,longest_streak_weeks,streak_started_week
       FROM members WHERE user_id=$1 ${lock ? 'FOR UPDATE' : ''}`,
      [id],
    );
  }

  countConfirmedSessions(memberId: string, start: Date, end: Date): Promise<number> {
    return sql
      .scalar<number>(
        `SELECT count(*)::int FROM attendances a JOIN sessions s ON s.id=a.session_id AND s.tenant_id=a.tenant_id
       WHERE a.member_id=$1 AND a.attendance_status='CONFIRMED_PASS' AND s.starts_at >= $2 AND s.starts_at < $3`,
        [memberId, start, end],
      )
      .then((value) => value ?? 0);
  }

  log(memberId: string, weekStart: string): Promise<StreakLog | null> {
    return sql.one<StreakLog>(
      `SELECT week_start,sessions_count,target_sessions,result,streak_before,streak_after,freeze_grant_id,created_at
       FROM streak_logs WHERE member_id=$1 AND week_start=$2`,
      [memberId, weekStart],
    );
  }

  updateMember(memberId: string, current: number, longest: number, startedWeek: string | null) {
    return sql.exec(
      `UPDATE members SET current_streak_weeks=$2,longest_streak_weeks=$3,streak_started_week=$4,updated_at=now()
       WHERE user_id=$1`,
      [memberId, current, longest, startedWeek],
    );
  }

  async claimFreeze(
    memberId: string,
    now: Date,
    monthStart: Date,
    nextMonthStart: Date,
    maxUses: number,
  ): Promise<string | null> {
    const grant = await sql.one<{ id: string }>(
      `SELECT id FROM streak_freeze_grants WHERE member_id=$1 AND used_at IS NULL
       AND (expires_at IS NULL OR expires_at > $2) ORDER BY granted_at,id FOR UPDATE SKIP LOCKED LIMIT 1`,
      [memberId, now],
    );
    if (!grant) return null;
    const used = await sql.scalar<number>(
      `SELECT count(*)::int FROM streak_freeze_grants WHERE member_id=$1 AND used_at >= $2 AND used_at < $3`,
      [memberId, monthStart, nextMonthStart],
    );
    return (used ?? 0) < maxUses ? grant.id : null;
  }

  useFreeze(id: string, weekStart: string, now: Date) {
    return sql.exec(
      'UPDATE streak_freeze_grants SET used_week_start=$2,used_at=$3 WHERE id=$1 AND used_at IS NULL',
      [id, weekStart, now],
    );
  }

  async grantMonthlyFreeze(memberId: string, month: string, expiresAt: Date): Promise<boolean> {
    const inserted = await sql.exec(
      `INSERT INTO streak_freeze_grants (tenant_id,member_id,grant_source,granted_for_month,expires_at)
       VALUES ($1,$2,'MONTHLY',$3,$4) ON CONFLICT (member_id,granted_for_month) WHERE (grant_source='MONTHLY') DO NOTHING`,
      [db.currentTenantId(), memberId, month, expiresAt],
    );
    return inserted === 1;
  }

  insertLog(input: Omit<StreakLog, 'createdAt'> & { memberId: string }) {
    return sql.exec(
      `INSERT INTO streak_logs (tenant_id,member_id,week_start,sessions_count,target_sessions,result,streak_before,streak_after,freeze_grant_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT (member_id,week_start) DO NOTHING`,
      [
        db.currentTenantId(),
        input.memberId,
        input.weekStart,
        input.sessionsCount,
        input.targetSessions,
        input.result,
        input.streakBefore,
        input.streakAfter,
        input.freezeGrantId,
      ],
    );
  }

  async availableFreezes(memberId: string, now: Date): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*)::int FROM streak_freeze_grants WHERE member_id=$1 AND used_at IS NULL
       AND (expires_at IS NULL OR expires_at > $2)`,
        [memberId, now],
      )) ?? 0
    );
  }

  recentLogs(memberId: string, limit = 12): Promise<StreakLog[]> {
    return sql.many<StreakLog>(
      `SELECT week_start,sessions_count,target_sessions,result,streak_before,streak_after,freeze_grant_id,created_at
       FROM streak_logs WHERE member_id=$1 ORDER BY week_start DESC LIMIT $2`,
      [memberId, limit],
    );
  }
}
