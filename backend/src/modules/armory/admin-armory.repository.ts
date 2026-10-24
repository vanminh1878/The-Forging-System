import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { AdminRewardFilter, CreateRewardInput, CreateTierInput } from './admin-armory.validation';

export type AdminRewardWrite = Omit<CreateRewardInput, 'saleStartsAt' | 'saleEndsAt'> & { saleStartsAt: Date | null; saleEndsAt: Date | null };
export interface AdminReward extends AdminRewardWrite { id: string; createdAt: Date; updatedAt: Date }
const rewardColumns = `id,sku,name,description,image_url,tier_code,marks_cost,stock,per_member_limit,limit_period,
  min_rank_id,pickup_days,sale_starts_at,sale_ends_at,is_active,created_at,updated_at`;
const tierColumns = `code,name,min_marks,max_marks,sort_order`;

export class AdminArmoryRepository {
  tiers() { return sql.many<CreateTierInput>(`SELECT ${tierColumns} FROM reward_tiers ORDER BY sort_order,code`); }
  tier(code: string, lock = false) {
    return sql.one<CreateTierInput>(`SELECT ${tierColumns} FROM reward_tiers WHERE code=$1 ${lock ? 'FOR UPDATE' : ''}`, [code]);
  }
  async tierCodeExists(code: string) { return !!await sql.scalar('SELECT 1 FROM reward_tiers WHERE upper(code)=$1', [code]); }
  async skuExists(sku: string) { return !!await sql.scalar('SELECT 1 FROM rewards WHERE upper(sku)=$1', [sku]); }
  async rankExists(id: string) { return !!await sql.scalar('SELECT 1 FROM ranks WHERE id=$1', [id]); }

  async createTier(input: CreateTierInput) {
    return (await sql.one<CreateTierInput>(`INSERT INTO reward_tiers (tenant_id,code,name,min_marks,max_marks,sort_order)
      VALUES ($1,$2,$3,$4,$5,$6) RETURNING ${tierColumns}`, [db.currentTenantId(), input.code, input.name, input.minMarks, input.maxMarks, input.sortOrder]))!;
  }
  async updateTier(input: CreateTierInput) {
    return (await sql.one<CreateTierInput>(`UPDATE reward_tiers SET name=$2,min_marks=$3,max_marks=$4,sort_order=$5
      WHERE code=$1 RETURNING ${tierColumns}`, [input.code, input.name, input.minMarks, input.maxMarks, input.sortOrder]))!;
  }
  reward(id: string, lock = false) {
    return sql.one<AdminReward>(`SELECT ${rewardColumns} FROM rewards WHERE id=$1 ${lock ? 'FOR UPDATE' : ''}`, [id]);
  }
  async createReward(input: AdminRewardWrite) {
    return (await sql.one<AdminReward>(`INSERT INTO rewards (tenant_id,sku,name,description,image_url,tier_code,marks_cost,stock,
      per_member_limit,limit_period,min_rank_id,pickup_days,sale_starts_at,sale_ends_at,is_active)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING ${rewardColumns}`, [db.currentTenantId(), ...this.values(input)]))!;
  }
  async updateReward(id: string, input: AdminRewardWrite) {
    return (await sql.one<AdminReward>(`UPDATE rewards SET sku=$2,name=$3,description=$4,image_url=$5,tier_code=$6,marks_cost=$7,stock=$8,
      per_member_limit=$9,limit_period=$10,min_rank_id=$11,pickup_days=$12,sale_starts_at=$13,sale_ends_at=$14,is_active=$15,updated_at=now()
      WHERE id=$1 RETURNING ${rewardColumns}`, [id, ...this.values(input)]))!;
  }
  inventory(rewardId: string, delta: number, actorId: string, reason: string) {
    return sql.exec(`INSERT INTO inventory_movements (tenant_id,reward_id,movement_type,quantity,actor_id,reason)
      VALUES ($1,$2,$3,$4,$5,$6)`, [db.currentTenantId(), rewardId, delta > 0 ? 'IN' : 'OUT', Math.abs(delta), actorId, reason]);
  }
  async search(filter: AdminRewardFilter, limit: number, offset: number) {
    const params = [filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null, filter.tierCode ?? null, filter.isActive ?? null];
    const where = `($1::text IS NULL OR name ILIKE $1 OR sku ILIKE $1) AND ($2::text IS NULL OR tier_code=$2)
      AND ($3::boolean IS NULL OR is_active=$3)`;
    const items = await sql.many<AdminReward>(`SELECT ${rewardColumns} FROM rewards WHERE ${where} ORDER BY created_at DESC,id DESC LIMIT $4 OFFSET $5`, [...params, limit, offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM rewards WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }
  private values(input: AdminRewardWrite): unknown[] {
    return [input.sku, input.name, input.description, input.imageUrl, input.tierCode, input.marksCost, input.stock,
      input.perMemberLimit, input.limitPeriod, input.minRankId, input.pickupDays, input.saleStartsAt, input.saleEndsAt, input.isActive];
  }
}
