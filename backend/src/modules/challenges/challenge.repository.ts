import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { ChallengeFilter, CreateChallengeInput } from './challenge.validation';

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
  participationStatus: 'JOINED' | 'AWAITING_COACH' | 'REWARDED' | 'EXPIRED' | null;
  progressValue: number | null;
  joinedAt: Date | null;
}

export interface ChallengeParticipationView {
  id: string;
  challengeId: string;
  memberId: string;
  status: 'JOINED' | 'AWAITING_COACH' | 'REWARDED' | 'EXPIRED';
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

export type ChallengeWrite = Omit<CreateChallengeInput, 'startsAt' | 'endsAt'> & { startsAt: Date; endsAt: Date };
const columns = `id, code, title, description, challenge_type, context, target, reward_dp,
  reward_marks, starts_at, ends_at, status, created_by, created_at, updated_at`;

export class ChallengeRepository {
  find(id: string, lock = false): Promise<ChallengeView | null> {
    return sql.one<ChallengeView>(`SELECT ${columns} FROM challenges WHERE id=$1 ${lock ? 'FOR UPDATE' : ''}`, [id]);
  }

  async codeExists(code: string, exceptId: string | null = null): Promise<boolean> {
    return !!await sql.scalar(`SELECT 1 FROM challenges WHERE code=$1 AND ($2::uuid IS NULL OR id<>$2)`, [code, exceptId]);
  }

  async hasParticipants(id: string): Promise<boolean> {
    return !!await sql.scalar(`SELECT 1 FROM challenge_participations WHERE challenge_id=$1 LIMIT 1`, [id]);
  }

  async create(input: ChallengeWrite, actorId: string): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(`INSERT INTO challenges
      (tenant_id,code,title,description,challenge_type,context,target,reward_dp,reward_marks,starts_at,ends_at,status,created_by)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'DRAFT',$12) RETURNING ${columns}`,
    [db.currentTenantId(), ...this.values(input), actorId]);
    return row!;
  }

  async update(id: string, input: ChallengeWrite): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(`UPDATE challenges SET
      code=$2,title=$3,description=$4,challenge_type=$5,context=$6,target=$7,reward_dp=$8,reward_marks=$9,
      starts_at=$10,ends_at=$11,updated_at=now() WHERE id=$1 RETURNING ${columns}`, [id, ...this.values(input)]);
    return row!;
  }

  async search(filter: ChallengeFilter, limit: number, offset: number) {
    const params = [filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null, filter.status ?? null, filter.challengeType ?? null, filter.context ?? null];
    const where = `($1::text IS NULL OR title ILIKE $1 OR code ILIKE $1)
      AND ($2::text IS NULL OR status=$2) AND ($3::text IS NULL OR challenge_type=$3) AND ($4::text IS NULL OR context=$4)`;
    const items = await sql.many<ChallengeView>(`SELECT ${columns} FROM challenges WHERE ${where} ORDER BY created_at DESC,id DESC LIMIT $5 OFFSET $6`, [...params, limit, offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM challenges WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  async setStatus(id: string, status: 'OPEN' | 'CLOSED'): Promise<ChallengeView> {
    const row = await sql.one<ChallengeView>(`UPDATE challenges SET status=$2, updated_at=now()
      WHERE id=$1 RETURNING ${columns}`, [id, status]);
    return row!;
  }

  async listOpenForMember(memberId: string, challengeType: string | null, context: string | null, q: string | null, now: Date, limit: number, offset: number) {
    const like = q ? `%${q.replace(/[\\%_]/g, '\\$&')}%` : null;
    const params: unknown[] = [memberId, challengeType, context, like, now];
    const where = `c.status='OPEN'
      AND c.ends_at > $5
      AND ($2::text IS NULL OR c.challenge_type=$2)
      AND ($3::text IS NULL OR c.context=$3)
      AND ($4::text IS NULL OR c.title ILIKE $4 OR c.code ILIKE $4)`;
    const items = await sql.many<OpenChallengeView>(`SELECT ${columns.replace(/(^|, )/g, '$1c.')}, p.id AS participation_id, p.status AS participation_status,
        p.progress_value, p.joined_at
      FROM challenges c
      LEFT JOIN challenge_participations p ON p.challenge_id=c.id AND p.member_id=$1
      WHERE ${where}
      ORDER BY c.ends_at ASC, c.id DESC
      LIMIT $6 OFFSET $7`, [...params, limit, offset]);
    const countParams = [challengeType, context, like, now];
    const countWhere = `status='OPEN'
      AND ends_at > $4
      AND ($1::text IS NULL OR challenge_type=$1)
      AND ($2::text IS NULL OR context=$2)
      AND ($3::text IS NULL OR title ILIKE $3 OR code ILIKE $3)`;
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM challenges WHERE ${countWhere}`, countParams);
    return { items, total: total ?? 0 };
  }

  async findParticipation(challengeId: string, memberId: string): Promise<ChallengeParticipationView | null> {
    const columns = `id, challenge_id, member_id, status, progress_value, evidence_url, evidence_at, joined_at, completed_at, confirmed_by, confirmed_at, is_limited, rewarded_at, updated_at`;
    return sql.one<ChallengeParticipationView>(`SELECT ${columns} FROM challenge_participations WHERE challenge_id=$1 AND member_id=$2`, [challengeId, memberId]);
  }

  async insertParticipation(challengeId: string, memberId: string): Promise<ChallengeParticipationView> {
    const row = await sql.one<ChallengeParticipationView>(`INSERT INTO challenge_participations (tenant_id, challenge_id, member_id)
      VALUES ($1,$2,$3) RETURNING id, challenge_id, member_id, status, progress_value, evidence_url, evidence_at, joined_at, completed_at, confirmed_by, confirmed_at, is_limited, rewarded_at, updated_at`,
      [db.currentTenantId(), challengeId, memberId]);
    return row!;
  }

  private values(input: ChallengeWrite): unknown[] {
    return [input.code, input.title, input.description, input.challengeType, input.context, input.target, input.rewardDp, input.rewardMarks, input.startsAt, input.endsAt];
  }
}
