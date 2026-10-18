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

  private values(input: ChallengeWrite): unknown[] {
    return [input.code, input.title, input.description, input.challengeType, input.context, input.target, input.rewardDp, input.rewardMarks, input.startsAt, input.endsAt];
  }
}
