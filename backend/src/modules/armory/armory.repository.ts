import { sql } from '../../db/sql';

export interface RewardTier {
  code: string;
  name: string;
  minMarks: number;
  maxMarks: number | null;
  sortOrder: number;
}

export interface RewardFilter { q?: string; tierCode?: string }

export interface RewardView {
  id: string;
  sku: string;
  name: string;
  description: string | null;
  imageUrl: string | null;
  tierCode: string | null;
  tierName: string | null;
  marksCost: number;
  stock: number;
  perMemberLimit: number | null;
  limitPeriod: string | null;
  minRankId: string | null;
  minRankOrder: number | null;
  minRankName: string | null;
  pickupDays: number | null;
  saleStartsAt: Date | null;
  saleEndsAt: Date | null;
}

export class ArmoryRepository {
  tiers() {
    return sql.many<RewardTier>(`SELECT code,name,min_marks,max_marks,sort_order FROM reward_tiers ORDER BY sort_order,code`);
  }

  async rewards(filter: RewardFilter, at: Date, limit: number, offset: number) {
    const params = [at, filter.tierCode ?? null, filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null];
    const where = `r.is_active=true AND (r.sale_starts_at IS NULL OR r.sale_starts_at <= $1)
      AND (r.sale_ends_at IS NULL OR r.sale_ends_at > $1)
      AND ($2::text IS NULL OR r.tier_code=$2) AND ($3::text IS NULL OR r.name ILIKE $3 OR r.sku ILIKE $3)`;
    const items = await sql.many<RewardView>(`SELECT r.id,r.sku,r.name,r.description,r.image_url,r.tier_code,t.name AS tier_name,
      r.marks_cost,r.stock,r.per_member_limit,r.limit_period,r.min_rank_id,k.rank_order AS min_rank_order,
      k.name_en AS min_rank_name,r.pickup_days,r.sale_starts_at,r.sale_ends_at
      FROM rewards r LEFT JOIN reward_tiers t ON t.tenant_id=r.tenant_id AND t.code=r.tier_code
      LEFT JOIN ranks k ON k.id=r.min_rank_id AND k.tenant_id=r.tenant_id
      WHERE ${where} ORDER BY t.sort_order NULLS LAST,r.tier_code NULLS LAST,r.marks_cost,r.name,r.id LIMIT $4 OFFSET $5`,
    [...params, limit, offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM rewards r WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }
}
