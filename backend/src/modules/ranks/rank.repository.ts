import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { RankDef, TrialStatus } from './rank.engine';

export interface MemberRankRow {
  userId: string;
  fullName: string;
  status: string;
  joinedAt: Date;
  dpBalance: number;
  currentRankId: string | null;
  peakRankId: string | null;
  homeBranchId: string | null;
}

export interface RankTrialRow {
  id: string;
  memberId: string;
  targetRankId: string;
  status: TrialStatus;
  approverRole: 'COACH' | 'HEAD_COACH' | 'ADMIN';
  assignedTo: string | null;
  scheduledAt: Date | null;
  eligibilitySnapshot: Record<string, unknown>;
  resultNote: string | null;
  evaluatedBy: string | null;
  evaluatedAt: Date | null;
  requestedAt: Date;
  memberName?: string;
  targetRankName?: string;
  targetRankOrder?: number;
}

export interface RankHistoryRow {
  id: string;
  memberId: string;
  fromRankId: string | null;
  toRankId: string;
  earnedVia: string;
  reason: string;
  dpAtChange: number;
  isRevoked: boolean;
  revokedAt: Date | null;
  earnedAt: Date;
}

export class RankRepository {
  async listRanks(): Promise<RankDef[]> {
    const rows = await sql.many<Omit<RankDef, 'requiredCourseIds'> & { requiredCourseIds: string[] | null }>(
      `SELECT r.id, r.rank_order, r.code, r.name_en, r.name_vi, r.dp_threshold, r.min_active_months,
              r.requires_trial, r.approval_role, r.is_honorary,
              COALESCE(array_agg(rc.course_id) FILTER (WHERE rc.course_id IS NOT NULL), '{}') AS required_course_ids
         FROM ranks r LEFT JOIN rank_required_courses rc ON rc.rank_id = r.id
        GROUP BY r.id ORDER BY r.rank_order`,
    );
    return rows.map((r) => ({ ...r, requiredCourseIds: r.requiredCourseIds ?? [] }));
  }

  memberState(memberId: string, lock = false): Promise<MemberRankRow | null> {
    return sql.one<MemberRankRow>(
      `SELECT m.user_id, u.full_name, m.status, m.joined_at, m.dp_balance, m.current_rank_id, m.peak_rank_id, m.home_branch_id
         FROM members m JOIN users u ON u.id = m.user_id
        WHERE m.user_id = $1 ${lock ? 'FOR UPDATE OF m' : ''}`,
      [memberId],
    );
  }

  async completedCourseIds(memberId: string): Promise<Set<string>> {
    const rows = await sql.many<{ courseId: string }>(
      `SELECT course_id FROM course_enrollments WHERE member_id = $1 AND status = 'COMPLETED'`,
      [memberId],
    );
    return new Set(rows.map((r) => r.courseId));
  }

  async latestTrialStatus(memberId: string, rankId: string): Promise<TrialStatus | null> {
    const row = await sql.one<{ status: TrialStatus }>(
      `SELECT status FROM rank_trial_requests WHERE member_id = $1 AND target_rank_id = $2
        ORDER BY requested_at DESC LIMIT 1`,
      [memberId, rankId],
    );
    return row?.status ?? null;
  }

  setRanks(memberId: string, currentRankId: string, peakRankId: string): Promise<number> {
    return sql.exec(`UPDATE members SET current_rank_id = $2, peak_rank_id = $3, updated_at = now() WHERE user_id = $1`, [
      memberId,
      currentRankId,
      peakRankId,
    ]);
  }

  insertHistory(input: {
    memberId: string;
    fromRankId: string | null;
    toRankId: string;
    earnedVia: string;
    reason: string;
    dpAtChange: number;
    isRevoked?: boolean;
    trialId?: string | null;
    approvedBy?: string | null;
  }): Promise<number> {
    return sql.exec(
      `INSERT INTO member_rank_history
         (tenant_id, member_id, from_rank_id, to_rank_id, earned_via, reason, rank_trial_request_id, dp_at_change,
          approved_by, is_revoked, revoked_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, CASE WHEN $10 THEN now() END)`,
      [
        db.currentTenantId(),
        input.memberId,
        input.fromRankId,
        input.toRankId,
        input.earnedVia,
        input.reason,
        input.trialId ?? null,
        input.dpAtChange,
        input.approvedBy ?? null,
        input.isRevoked ?? false,
      ],
    );
  }

  /** Badges currently held: the latest history row of each rank, if not revoked. */
  currentBadges(memberId: string): Promise<(RankHistoryRow & { rankOrder: number; nameEn: string; nameVi: string | null; badgeUrl: string | null })[]> {
    return sql.many(
      `SELECT h.*, r.rank_order, r.name_en, r.name_vi, r.badge_url
         FROM (SELECT DISTINCT ON (to_rank_id) * FROM member_rank_history WHERE member_id = $1
                ORDER BY to_rank_id, earned_at DESC, id) h
         JOIN ranks r ON r.id = h.to_rank_id
        WHERE NOT h.is_revoked ORDER BY r.rank_order`,
      [memberId],
    );
  }

  history(memberId: string, limit: number): Promise<RankHistoryRow[]> {
    return sql.many<RankHistoryRow>(
      `SELECT * FROM member_rank_history WHERE member_id = $1 ORDER BY earned_at DESC LIMIT $2`,
      [memberId, limit],
    );
  }

  // ---------- trials ----------

  insertTrial(input: { memberId: string; targetRankId: string; approverRole: string; snapshot: unknown }): Promise<RankTrialRow | null> {
    return sql.one<RankTrialRow>(
      `INSERT INTO rank_trial_requests (tenant_id, member_id, target_rank_id, approver_role, eligibility_snapshot)
       VALUES ($1,$2,$3,$4,$5::jsonb) RETURNING *`,
      [db.currentTenantId(), input.memberId, input.targetRankId, input.approverRole, JSON.stringify(input.snapshot)],
    );
  }

  getTrial(id: string, lock = false): Promise<RankTrialRow | null> {
    return sql.one<RankTrialRow>(`SELECT * FROM rank_trial_requests WHERE id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id]);
  }

  updateTrial(input: {
    id: string;
    status: TrialStatus;
    evaluatedBy: string | null;
    note: string | null;
    snapshot?: unknown;
  }): Promise<number> {
    return sql.exec(
      `UPDATE rank_trial_requests
          SET status = $2, evaluated_by = $3, evaluated_at = CASE WHEN $2 IN ('PASSED','FAILED','CANCELLED') THEN now() ELSE evaluated_at END,
              result_note = $4, eligibility_snapshot = COALESCE($5::jsonb, eligibility_snapshot), updated_at = now()
        WHERE id = $1`,
      [input.id, input.status, input.evaluatedBy, input.note, input.snapshot === undefined ? null : JSON.stringify(input.snapshot)],
    );
  }

  listTrials(filter: { status?: string[]; approverRoles?: string[]; memberId?: string }, limit: number): Promise<RankTrialRow[]> {
    return sql.many<RankTrialRow>(
      `SELECT t.*, u.full_name AS member_name, r.name_en AS target_rank_name, r.rank_order AS target_rank_order
         FROM rank_trial_requests t
         JOIN users u ON u.id = t.member_id
         JOIN ranks r ON r.id = t.target_rank_id
        WHERE ($1::text[] IS NULL OR t.status = ANY($1))
          AND ($2::text[] IS NULL OR t.approver_role = ANY($2))
          AND ($3::uuid IS NULL OR t.member_id = $3)
        ORDER BY t.requested_at DESC LIMIT $4`,
      [filter.status ?? null, filter.approverRoles ?? null, filter.memberId ?? null, limit],
    );
  }

  async courseNames(ids: string[]): Promise<Map<string, string>> {
    if (ids.length === 0) return new Map();
    const rows = await sql.many<{ id: string; name: string }>(`SELECT id, name FROM courses WHERE id = ANY($1::uuid[])`, [ids]);
    return new Map(rows.map((r) => [r.id, r.name]));
  }
}
