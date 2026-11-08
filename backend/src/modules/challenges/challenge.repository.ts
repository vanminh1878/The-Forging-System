import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { ChallengeFilter, CreateChallengeInput, StaffParticipationFilter } from './challenge.validation';

export interface ChallengeView extends Omit<CreateChallengeInput, 'startsAt' | 'endsAt'> {
  id: string;
  startsAt: Date;
  endsAt: Date;
  status: 'DRAFT' | 'OPEN' | 'CLOSED' | 'CANCELLED';
  createdBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OpenChallengeView extends ChallengeView {
  participationId: string | null;
  participationStatus: 'PENDING_COACH' | 'JOINED' | 'AWAITING_COACH' | 'REWARDED' | 'EXPIRED' | null;
  progressValue: number | null;
  joinedAt: Date | null;
  evidenceUrl: string | null;
}

export interface ChallengeParticipationView {
  id: string;
  challengeId: string;
  memberId: string;
  status: 'PENDING_COACH' | 'JOINED' | 'AWAITING_COACH' | 'REWARDED' | 'EXPIRED';
  progressValue: number;
  evidenceUrl: string | null;
  evidenceAt: Date | null;
  joinedAt: Date;
  completedAt: Date | null;
  confirmedBy: string | null;
  confirmedAt: Date | null;
  isLimited: boolean;
  rewardedAt: Date | null;
  updatedAt: Date;
}

export interface ChallengeProgressUpdate {
  participation: ChallengeParticipationView;
  target: number;
}

export interface StaffChallengeParticipationView extends ChallengeParticipationView {
  challengeTitle: string;
  challengeType: string;
  target: number;
  memberCode: string;
  memberFullName: string;
}

type ChallengeProgressRow = ChallengeParticipationView & { target: number };

export type ChallengeWrite = Omit<CreateChallengeInput, 'startsAt' | 'endsAt'> & {
  startsAt: Date;
  endsAt: Date;
};
const columns = `id, code, title, description, challenge_type, context, target, reward_dp,
  reward_marks, starts_at, ends_at, status, created_by, created_at, updated_at`;

export class ChallengeRepository {
  find(id: string, lock = false): Promise<ChallengeView | null> {
    return sql.one<ChallengeView>(
      `SELECT ${columns} FROM challenges WHERE id=$1 ${lock ? 'FOR UPDATE' : ''}`,
      [id],
    );
  }

  async codeExists(code: string, exceptId: string | null = null): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM challenges WHERE code=$1 AND ($2::uuid IS NULL OR id<>$2)`, [
      code,
      exceptId,
    ]));
  }

  async hasParticipants(id: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM challenge_participations WHERE challenge_id=$1 LIMIT 1`, [id]));
  }

  async create(input: ChallengeWrite, actorId: string): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(
      `INSERT INTO challenges
      (tenant_id,code,title,description,challenge_type,context,target,reward_dp,reward_marks,starts_at,ends_at,status,created_by)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'DRAFT',$12) RETURNING ${columns}`,
      [db.currentTenantId(), ...this.values(input), actorId],
    );
    return row!;
  }

  async update(id: string, input: ChallengeWrite): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(
      `UPDATE challenges SET
      code=$2,title=$3,description=$4,challenge_type=$5,context=$6,target=$7,reward_dp=$8,reward_marks=$9,
      starts_at=$10,ends_at=$11,updated_at=now() WHERE id=$1 RETURNING ${columns}`,
      [id, ...this.values(input)],
    );
    return row!;
  }

  async search(filter: ChallengeFilter, limit: number, offset: number) {
    const params = [
      filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null,
      filter.status ?? null,
      filter.challengeType ?? null,
      filter.context ?? null,
    ];
    const where = `($1::text IS NULL OR title ILIKE $1 OR code ILIKE $1)
      AND ($2::text IS NULL OR status=$2) AND ($3::text IS NULL OR challenge_type=$3) AND ($4::text IS NULL OR context=$4)`;
    const items = await sql.many<ChallengeView>(
      `SELECT ${columns} FROM challenges WHERE ${where} ORDER BY created_at DESC,id DESC LIMIT $5 OFFSET $6`,
      [...params, limit, offset],
    );
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM challenges WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  async setStatus(id: string, status: 'OPEN' | 'CLOSED'): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(
      `UPDATE challenges SET status=$2, updated_at=now()
      WHERE id=$1 RETURNING ${columns}`,
      [id, status],
    );
    return row!;
  }

  async listOpenForMember(
    memberId: string,
    challengeType: string | null,
    context: string | null,
    q: string | null,
    now: Date,
    limit: number,
    offset: number,
  ) {
    const like = q ? `%${q.replace(/[\\%_]/g, '\\$&')}%` : null;
    const params: unknown[] = [memberId, challengeType, context, like, now];
    const where = `c.status='OPEN'
      AND c.ends_at > $5
      AND ($2::text IS NULL OR c.challenge_type=$2)
      AND ($3::text IS NULL OR c.context=$3)
      AND ($4::text IS NULL OR c.title ILIKE $4 OR c.code ILIKE $4)`;
    const items = await sql.many<OpenChallengeView>(
      `SELECT ${columns.replace(/(^|, )/g, '$1c.')}, p.id AS participation_id, p.status AS participation_status,
        p.progress_value, p.joined_at, p.evidence_url
      FROM challenges c
      LEFT JOIN challenge_participations p ON p.challenge_id=c.id AND p.member_id=$1
      WHERE ${where}
      ORDER BY c.ends_at ASC, c.id DESC
      LIMIT $6 OFFSET $7`,
      [...params, limit, offset],
    );
    const countParams = [challengeType, context, like, now];
    const countWhere = `status='OPEN'
      AND ends_at > $4
      AND ($1::text IS NULL OR challenge_type=$1)
      AND ($2::text IS NULL OR context=$2)
      AND ($3::text IS NULL OR title ILIKE $3 OR code ILIKE $3)`;
    const total = await sql.scalar<number>(
      `SELECT count(*)::int FROM challenges WHERE ${countWhere}`,
      countParams,
    );
    return { items, total: total ?? 0 };
  }

  async findParticipation(
    challengeId: string,
    memberId: string,
    lock = false,
  ): Promise<ChallengeParticipationView | null> {
    const columns = `id, challenge_id, member_id, status, progress_value, evidence_url, evidence_at, joined_at, completed_at, confirmed_by, confirmed_at, is_limited, rewarded_at, updated_at`;
    return sql.one<ChallengeParticipationView>(
      `SELECT ${columns} FROM challenge_participations WHERE challenge_id=$1 AND member_id=$2 ${lock ? 'FOR UPDATE' : ''}`,
      [challengeId, memberId],
    );
  }

  async findParticipationById(id: string, lock = false): Promise<ChallengeParticipationView | null> {
    const columns = `id, challenge_id, member_id, status, progress_value, evidence_url, evidence_at, joined_at, completed_at, confirmed_by, confirmed_at, is_limited, rewarded_at, updated_at`;
    return sql.one<ChallengeParticipationView>(
      `SELECT ${columns} FROM challenge_participations WHERE id=$1 ${lock ? 'FOR UPDATE' : ''}`,
      [id],
    );
  }

  async insertParticipation(challengeId: string, memberId: string): Promise<ChallengeParticipationView> {
    const row = await sql.one<ChallengeParticipationView>(
      `INSERT INTO challenge_participations (tenant_id, challenge_id, member_id, status)
      VALUES ($1,$2,$3,'PENDING_COACH') RETURNING id, challenge_id, member_id, status, progress_value, evidence_url, evidence_at, joined_at, completed_at, confirmed_by, confirmed_at, is_limited, rewarded_at, updated_at`,
      [db.currentTenantId(), challengeId, memberId],
    );
    return row!;
  }

  /**
   * Applies one confirmed attendance to every matching joined participation.
   * The progress-event unique key makes replaying the same domain event a no-op.
   */
  async recordAttendanceProgress(
    memberId: string,
    attendanceId: string,
    context: 'SESSION' | 'WORKSHOP' | 'EXAM',
    occurredAt: Date,
  ): Promise<ChallengeProgressUpdate[]> {
    const rows = await sql.many<ChallengeProgressRow>(
      `WITH eligible AS (
        SELECT p.id AS participation_id, c.target
        FROM challenge_participations p
        JOIN challenges c ON c.id=p.challenge_id
        WHERE p.member_id=$1 AND p.status='JOINED' AND c.status='OPEN'
          AND c.context=$3 AND c.starts_at <= $4 AND c.ends_at > $4
      ), recorded AS (
        INSERT INTO challenge_progress_events
          (tenant_id,challenge_participation_id,source_type,source_id,delta,occurred_at)
        SELECT $5,participation_id,'ATTENDANCE_CONFIRMED',$2,1,$4 FROM eligible
        ON CONFLICT (challenge_participation_id,source_type,source_id) DO NOTHING
        RETURNING challenge_participation_id
      ), updated AS (
        UPDATE challenge_participations p SET
          progress_value=LEAST(c.target,p.progress_value+1),
          status=CASE WHEN p.progress_value+1 >= c.target THEN 'AWAITING_COACH' ELSE 'JOINED' END,
          completed_at=CASE WHEN p.progress_value+1 >= c.target THEN $4 ELSE p.completed_at END,
          updated_at=now()
        FROM recorded r, challenges c
        WHERE p.id=r.challenge_participation_id AND c.id=p.challenge_id AND p.status='JOINED'
        RETURNING p.id,p.challenge_id,p.member_id,p.status,p.progress_value,p.evidence_url,p.evidence_at,
          p.joined_at,p.completed_at,p.confirmed_by,p.confirmed_at,p.is_limited,p.rewarded_at,p.updated_at,c.target
      )
      SELECT id,challenge_id,member_id,status,progress_value,evidence_url,evidence_at,joined_at,completed_at,
        confirmed_by,confirmed_at,is_limited,rewarded_at,updated_at,target FROM updated`,
      [memberId, attendanceId, context, occurredAt, db.currentTenantId()],
    );
    return rows.map((row) => ({
      participation: {
        id: row.id,
        challengeId: row.challengeId,
        memberId: row.memberId,
        status: row.status,
        progressValue: row.progressValue,
        evidenceUrl: row.evidenceUrl,
        evidenceAt: row.evidenceAt,
        joinedAt: row.joinedAt,
        completedAt: row.completedAt,
        confirmedBy: row.confirmedBy,
        confirmedAt: row.confirmedAt,
        isLimited: row.isLimited,
        rewardedAt: row.rewardedAt,
        updatedAt: row.updatedAt,
      },
      target: row.target,
    }));
  }

  async submitCompletionEvidence(id: string, evidenceUrl: string, at: Date): Promise<ChallengeParticipationView> {
    const row = await sql.one<ChallengeParticipationView>(
      `UPDATE challenge_participations
      SET evidence_url=$2,evidence_at=$3,status='AWAITING_COACH',completed_at=$3,updated_at=now() WHERE id=$1
      RETURNING id,challenge_id,member_id,status,progress_value,evidence_url,evidence_at,joined_at,completed_at,
        confirmed_by,confirmed_at,is_limited,rewarded_at,updated_at`,
      [id, evidenceUrl, at],
    );
    return row!;
  }

  async approveJoin(id: string, actorId: string, at: Date): Promise<ChallengeParticipationView> {
    const row = await sql.one<ChallengeParticipationView>(
      `UPDATE challenge_participations SET status='JOINED',confirmed_by=$2,confirmed_at=$3,updated_at=now()
       WHERE id=$1 RETURNING id,challenge_id,member_id,status,progress_value,evidence_url,evidence_at,joined_at,
         completed_at,confirmed_by,confirmed_at,is_limited,rewarded_at,updated_at`,
      [id, actorId, at],
    );
    return row!;
  }

  async lockMember(memberId: string): Promise<void> {
    await sql.one(`SELECT user_id FROM members WHERE user_id=$1 FOR UPDATE`, [memberId]);
  }

  async rewardedThisMonth(memberId: string, monthStartsAt: Date): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*)::int FROM challenge_participations
      WHERE member_id=$1 AND status='REWARDED' AND NOT is_limited AND rewarded_at >= $2`,
        [memberId, monthStartsAt],
      )) ?? 0
    );
  }

  async approveParticipation(
    id: string,
    actorId: string,
    at: Date,
    isLimited: boolean,
  ): Promise<ChallengeParticipationView> {
    const row = await sql.one<ChallengeParticipationView>(
      `UPDATE challenge_participations SET
      status='REWARDED',confirmed_by=$2,confirmed_at=$3,is_limited=$4,rewarded_at=$3,updated_at=now()
      WHERE id=$1 RETURNING id,challenge_id,member_id,status,progress_value,evidence_url,evidence_at,joined_at,
        completed_at,confirmed_by,confirmed_at,is_limited,rewarded_at,updated_at`,
      [id, actorId, at, isLimited],
    );
    return row!;
  }

  async staffParticipations(filter: StaffParticipationFilter, limit: number, offset: number) {
    const where = `($1::text IS NULL OR p.status=$1)
      AND ($2::text IS NULL OR ($2='SUBMITTED' AND p.evidence_url IS NOT NULL)
        OR ($2='PENDING' AND p.evidence_url IS NULL))
      AND ($3::text IS NULL OR c.title ILIKE '%' || $3 || '%'
        OR m.member_code ILIKE '%' || $3 || '%' OR u.full_name ILIKE '%' || $3 || '%')`;
    const params = [filter.status ?? null, filter.evidence ?? null, filter.q ?? null];
    const select = `p.id,p.challenge_id,p.member_id,p.status,p.progress_value,p.evidence_url,p.evidence_at,p.joined_at,
      p.completed_at,p.confirmed_by,p.confirmed_at,p.is_limited,p.rewarded_at,p.updated_at,
      c.title AS challenge_title,c.challenge_type,c.target,m.member_code,u.full_name AS member_full_name`;
    const from = `challenge_participations p JOIN challenges c ON c.id=p.challenge_id
      JOIN members m ON m.user_id=p.member_id JOIN users u ON u.id=p.member_id`;
    const items = await sql.many<StaffChallengeParticipationView>(
      `SELECT ${select} FROM ${from} WHERE ${where}
      ORDER BY CASE p.status WHEN 'AWAITING_COACH' THEN 0 ELSE 1 END,p.completed_at ASC,p.id ASC LIMIT $4 OFFSET $5`,
      [...params, limit, offset],
    );
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM ${from} WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  private values(input: ChallengeWrite): unknown[] {
    return [
      input.code,
      input.title,
      input.description,
      input.challengeType,
      input.context,
      input.target,
      input.rewardDp,
      input.rewardMarks,
      input.startsAt,
      input.endsAt,
    ];
  }
}
