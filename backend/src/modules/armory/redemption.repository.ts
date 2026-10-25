import { db } from '../../db/database';
import { sql } from '../../db/sql';

export interface RedeemingMember {
  id: string;
  status: string;
  accountStatus: string;
  rankOrder: number | null;
}

export interface RedeemableReward {
  id: string;
  marksCost: number;
  stock: number;
  isActive: boolean;
  minRankId: string | null;
  minRankOrder: number | null;
  perMemberLimit: number | null;
  limitPeriod: 'MONTH' | 'YEAR' | 'LIFETIME' | null;
  saleStartsAt: Date | null;
  saleEndsAt: Date | null;
}

export interface RedemptionView {
  id: string;
  redemptionCode: string;
  rewardId: string;
  pickupBranchId: string;
  marksCost: number;
  status: string;
  requestedAt: Date;
}

export interface MemberRedemptionView extends RedemptionView {
  rewardSku: string;
  rewardName: string;
  rewardImageUrl: string | null;
  pickupBranchName: string;
  reason: string | null;
  decidedAt: Date | null;
}

export interface RedemptionFilter { status?: 'PENDING_PICKUP' | 'DELIVERED' | 'REJECTED' | 'CANCELLED' | 'EXPIRED' }

export interface RedemptionWallet {
  marksBalance: number;
  marksHeld: number;
  marksAvailable: number;
}

const orderColumns = 'id,redemption_code,reward_id,pickup_branch_id,marks_cost,status,requested_at';

export class RedemptionRepository {
  lockMember(id: string) {
    return sql.one<RedeemingMember>(`SELECT m.user_id AS id,m.status,u.account_status,k.rank_order
      FROM members m JOIN users u ON u.id=m.user_id AND u.tenant_id=m.tenant_id
      LEFT JOIN ranks k ON k.id=m.current_rank_id AND k.tenant_id=m.tenant_id
      WHERE m.user_id=$1 FOR UPDATE OF m`, [id]);
  }

  findByKey(memberId: string, key: string) {
    return sql.one<RedemptionView>(`SELECT ${orderColumns} FROM redemptions WHERE member_id=$1 AND idempotency_key=$2`, [memberId, key]);
  }

  async pickupBranchExists(id: string) {
    return !!await sql.scalar(`SELECT id FROM branches WHERE id=$1 AND is_active=true FOR SHARE`, [id]);
  }

  lockReward(id: string) {
    return sql.one<RedeemableReward>(`SELECT r.id,r.marks_cost,r.stock,r.is_active,r.min_rank_id,k.rank_order AS min_rank_order,
      r.per_member_limit,r.limit_period,r.sale_starts_at,r.sale_ends_at FROM rewards r
      LEFT JOIN ranks k ON k.id=r.min_rank_id AND k.tenant_id=r.tenant_id WHERE r.id=$1 FOR UPDATE OF r`, [id]);
  }

  /** Called after locking the member: use a fresh statement snapshot after lock waits. */
  async wallet(memberId: string): Promise<RedemptionWallet> {
    return (await sql.one<RedemptionWallet>(`SELECT m.marks_balance,COALESCE(h.held,0) AS marks_held,
      m.marks_balance-COALESCE(h.held,0) AS marks_available FROM members m LEFT JOIN LATERAL
      (SELECT SUM(marks_cost) AS held FROM redemptions WHERE member_id=m.user_id AND status='PENDING_PICKUP') h ON true
      WHERE m.user_id=$1`, [memberId]))!;
  }

  async memberRewardCount(memberId: string, rewardId: string, start: Date | null, end: Date | null) {
    return (await sql.scalar<number>(`SELECT count(*)::int FROM redemptions WHERE member_id=$1 AND reward_id=$2
      AND status IN ('PENDING_PICKUP','DELIVERED') AND ($3::timestamptz IS NULL OR requested_at >= $3)
      AND ($4::timestamptz IS NULL OR requested_at < $4)`, [memberId, rewardId, start, end])) ?? 0;
  }

  async create(input: { id: string; code: string; memberId: string; rewardId: string; pickupBranchId: string; marksCost: number; key: string; at: Date }) {
    return (await sql.one<RedemptionView>(`INSERT INTO redemptions
      (id,tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key,requested_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING ${orderColumns}`,
    [input.id, db.currentTenantId(), input.code, input.memberId, input.rewardId, input.pickupBranchId, input.marksCost, input.key, input.at]))!;
  }

  async listForMember(memberId: string, filter: RedemptionFilter, limit: number, offset: number) {
    const params = [memberId, filter.status ?? null];
    const where = `d.member_id=$1 AND ($2::text IS NULL OR d.status=$2)`;
    const items = await sql.many<MemberRedemptionView>(`SELECT d.id,d.redemption_code,d.reward_id,d.pickup_branch_id,d.marks_cost,d.status,d.requested_at,
      d.decided_at,d.reason,r.sku AS reward_sku,r.name AS reward_name,r.image_url AS reward_image_url,b.name AS pickup_branch_name
      FROM redemptions d JOIN rewards r ON r.id=d.reward_id AND r.tenant_id=d.tenant_id
      JOIN branches b ON b.id=d.pickup_branch_id AND b.tenant_id=d.tenant_id
      WHERE ${where} ORDER BY d.requested_at DESC,d.id DESC LIMIT $3 OFFSET $4`, [...params, limit, offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM redemptions d WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  findForMember(memberId: string, id: string): Promise<MemberRedemptionView | null> {
    return sql.one<MemberRedemptionView>(`SELECT d.id,d.redemption_code,d.reward_id,d.pickup_branch_id,d.marks_cost,d.status,d.requested_at,
      d.decided_at,d.reason,r.sku AS reward_sku,r.name AS reward_name,r.image_url AS reward_image_url,b.name AS pickup_branch_name
      FROM redemptions d JOIN rewards r ON r.id=d.reward_id AND r.tenant_id=d.tenant_id
      JOIN branches b ON b.id=d.pickup_branch_id AND b.tenant_id=d.tenant_id
      WHERE d.member_id=$1 AND d.id=$2`, [memberId, id]);
  }

  consumeStock(rewardId: string) { return sql.exec('UPDATE rewards SET stock=stock-1,updated_at=now() WHERE id=$1 AND stock>0', [rewardId]); }

  inventoryOut(rewardId: string, redemptionId: string, memberId: string) {
    return sql.exec(`INSERT INTO inventory_movements (tenant_id,reward_id,movement_type,quantity,redemption_id,actor_id,reason)
      VALUES ($1,$2,'OUT',1,$3,$4,'Stock allocated to pending redemption')`, [db.currentTenantId(), rewardId, redemptionId, memberId]);
  }
}
