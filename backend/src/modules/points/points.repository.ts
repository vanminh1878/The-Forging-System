import { db } from '../../db/database';
import { sql } from '../../db/sql';
import { CAP_SOURCES } from './points.rules';

export interface PointTransaction {
  id: string;
  memberId: string;
  source: string;
  dpAmount: number;
  marksAmount: number;
  isCapped: boolean;
  note: string | null;
  status: string;
  idempotencyKey: string | null;
  reversalOfId: string | null;
  attendanceId: string | null;
  challengeParticipationId: string | null;
  rankTrialRequestId: string | null;
  redemptionId: string | null;
  membershipId: string | null;
  reason: string | null;
  createdBy: string | null;
  occurredAt: Date;
}

export interface InsertTransaction {
  memberId: string;
  source: string;
  dpAmount: number;
  marksAmount: number;
  isCapped: boolean;
  note: string | null;
  idempotencyKey?: string | null;
  reversalOfId?: string | null;
  attendanceId?: string | null;
  challengeParticipationId?: string | null;
  rankTrialRequestId?: string | null;
  redemptionId?: string | null;
  membershipId?: string | null;
  reason?: string | null;
  createdBy?: string | null;
  occurredAt?: Date;
}

export class PointsRepository {
  insert(input: InsertTransaction): Promise<PointTransaction | null> {
    return sql.one<PointTransaction>(
      `INSERT INTO point_transactions
         (tenant_id, member_id, source, dp_amount, marks_amount, is_capped, note, idempotency_key, reversal_of_id,
          attendance_id, challenge_participation_id, rank_trial_request_id, redemption_id, membership_id, reason,
          created_by, occurred_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16, COALESCE($17, now()))
       ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING
       RETURNING *`,
      [
        db.currentTenantId(),
        input.memberId,
        input.source,
        input.dpAmount,
        input.marksAmount,
        input.isCapped,
        input.note,
        input.idempotencyKey ?? null,
        input.reversalOfId ?? null,
        input.attendanceId ?? null,
        input.challengeParticipationId ?? null,
        input.rankTrialRequestId ?? null,
        input.redemptionId ?? null,
        input.membershipId ?? null,
        input.reason ?? null,
        input.createdBy ?? null,
        input.occurredAt ?? null,
      ],
    );
  }

  findByIdempotencyKey(key: string): Promise<PointTransaction | null> {
    return sql.one<PointTransaction>(`SELECT * FROM point_transactions WHERE idempotency_key = $1`, [key]);
  }

  findById(id: string): Promise<PointTransaction | null> {
    return sql.one<PointTransaction>(`SELECT * FROM point_transactions WHERE id = $1`, [id]);
  }

  /** Locks the member row so concurrent awards cannot both slip under the monthly cap. */
  async lockMember(memberId: string): Promise<{ dpBalance: number; marksBalance: number } | null> {
    return sql.one(`SELECT dp_balance, marks_balance FROM members WHERE user_id = $1 FOR UPDATE`, [memberId]);
  }

  /** Sum of DP / Marks granted by cap-limited sources since `monthStart`. */
  async monthlyUsage(memberId: string, monthStart: Date): Promise<{ dp: number; marks: number }> {
    const row = await sql.one<{ dp: number; marks: number }>(
      `SELECT COALESCE(SUM(dp_amount), 0) AS dp, COALESCE(SUM(marks_amount), 0) AS marks
         FROM point_transactions
        WHERE member_id = $1 AND status = 'POSTED' AND occurred_at >= $2 AND source = ANY($3::text[])`,
      [memberId, monthStart, [...CAP_SOURCES]],
    );
    return { dp: Number(row?.dp ?? 0), marks: Number(row?.marks ?? 0) };
  }

  list(memberId: string, filter: { source?: string }, limit: number, offset: number) {
    return sql.many<PointTransaction>(
      `SELECT * FROM point_transactions
        WHERE member_id = $1 AND ($2::text IS NULL OR source = $2)
        ORDER BY occurred_at DESC, created_at DESC
        LIMIT $3 OFFSET $4`,
      [memberId, filter.source ?? null, limit, offset],
    );
  }

  async count(memberId: string, filter: { source?: string }): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*) FROM point_transactions WHERE member_id = $1 AND ($2::text IS NULL OR source = $2)`,
        [memberId, filter.source ?? null],
      )) ?? 0
    );
  }

  /** Reconciliation: cached balance vs. ledger sum (view v_member_balance_check). */
  reconcile(memberId: string) {
    return sql.one<{
      dpBalanceCache: number;
      dpBalanceLedger: number;
      marksBalanceCache: number;
      marksBalanceLedger: number;
    }>(`SELECT * FROM v_member_balance_check WHERE member_id = $1`, [memberId]);
  }
}
