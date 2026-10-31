import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { RedemptionHistoryFilter } from './redemption.validation';

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

export interface RedemptionHistoryView extends RedemptionView {
  rewardName: string;
  rewardSku: string;
  rewardImageUrl: string | null;
  pickupBranchName: string;
  decidedAt: Date | null;
  reason: string | null;
}

export interface RedemptionState extends RedemptionView {
  memberId: string;
  reason: string | null;
  decidedBy: string | null;
  decidedAt: Date | null;
  deliveryEvidenceUrl: string | null;
}

const orderColumns = 'id,redemption_code,reward_id,pickup_branch_id,marks_cost,status,requested_at';

export class RedemptionRepository {
  async history(memberId: string, filter: RedemptionHistoryFilter, limit: number, offset: number) {
    const where = `d.member_id=$1 AND ($2::text IS NULL OR d.status=$2)`;
    const params = [memberId, filter.status ?? null];
    const items = await sql.many<RedemptionHistoryView>(
      `SELECT d.id,d.redemption_code,d.reward_id,d.pickup_branch_id,
      d.marks_cost,d.status,d.requested_at,d.decided_at,d.reason,
      r.name AS reward_name,r.sku AS reward_sku,r.image_url AS reward_image_url,b.name AS pickup_branch_name
      FROM redemptions d JOIN rewards r ON r.id=d.reward_id AND r.tenant_id=d.tenant_id
      JOIN branches b ON b.id=d.pickup_branch_id AND b.tenant_id=d.tenant_id
      WHERE ${where} ORDER BY d.requested_at DESC,d.id DESC LIMIT $3 OFFSET $4`,
      [...params, limit, offset],
    );
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM redemptions d WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  detail(memberId: string, redemptionId: string): Promise<RedemptionHistoryView | null> {
    return sql.one<RedemptionHistoryView>(
      `SELECT d.id,d.redemption_code,d.reward_id,d.pickup_branch_id,
      d.marks_cost,d.status,d.requested_at,d.decided_at,d.reason,
      r.name AS reward_name,r.sku AS reward_sku,r.image_url AS reward_image_url,b.name AS pickup_branch_name
      FROM redemptions d JOIN rewards r ON r.id=d.reward_id AND r.tenant_id=d.tenant_id
      JOIN branches b ON b.id=d.pickup_branch_id AND b.tenant_id=d.tenant_id
      WHERE d.member_id=$1 AND d.id=$2`,
      [memberId, redemptionId],
    );
  }

  /** Read only to discover the member to lock; tenant isolation is enforced by RLS. */
  memberForOrder(id: string) {
    return sql.scalar<string>('SELECT member_id FROM redemptions WHERE id=$1', [id]);
  }

  lockOrder(id: string): Promise<RedemptionState | null> {
    return sql.one<RedemptionState>(
      `SELECT ${orderColumns},member_id,reason,decided_by,decided_at,delivery_evidence_url
      FROM redemptions WHERE id=$1 FOR UPDATE`,
      [id],
    );
  }

  async transition(
    id: string,
    status: string,
    actorId: string | null,
    reason: string | null,
    evidence: string | null,
  ) {
    return sql.one<RedemptionState>(
      `UPDATE redemptions SET status=$2,decided_by=$3,decided_at=now(),reason=$4,
      delivery_evidence_url=$5,updated_at=now() WHERE id=$1 AND status='PENDING_PICKUP'
      RETURNING ${orderColumns},member_id,reason,decided_by,decided_at,delivery_evidence_url`,
      [id, status, actorId, reason, evidence],
    );
  }

  async restoreStock(order: RedemptionState, actorId: string | null, reason: string) {
    const updated = await sql.exec('UPDATE rewards SET stock=stock+1,updated_at=now() WHERE id=$1', [
      order.rewardId,
    ]);
    if (updated !== 1) throw new Error('Cannot restore stock for redemption');
    await sql.exec(
      `INSERT INTO inventory_movements (tenant_id,reward_id,movement_type,quantity,redemption_id,actor_id,reason)
      VALUES ($1,$2,'IN',1,$3,$4,$5)`,
      [db.currentTenantId(), order.rewardId, order.id, actorId, reason],
    );
  }

  lockMember(id: string) {
    return sql.one<RedeemingMember>(
      `SELECT m.user_id AS id,m.status,u.account_status,k.rank_order
      FROM members m JOIN users u ON u.id=m.user_id AND u.tenant_id=m.tenant_id
      LEFT JOIN ranks k ON k.id=m.current_rank_id AND k.tenant_id=m.tenant_id
      WHERE m.user_id=$1 FOR UPDATE OF m`,
      [id],
    );
  }

  findByKey(memberId: string, key: string) {
    return sql.one<RedemptionView>(
      `SELECT ${orderColumns} FROM redemptions WHERE member_id=$1 AND idempotency_key=$2`,
      [memberId, key],
    );
  }

  async pickupBranchExists(id: string) {
    return !!(await sql.scalar(`SELECT id FROM branches WHERE id=$1 AND is_active=true FOR SHARE`, [id]));
  }

  lockReward(id: string) {
    return sql.one<RedeemableReward>(
      `SELECT r.id,r.marks_cost,r.stock,r.is_active,r.min_rank_id,k.rank_order AS min_rank_order,
      r.per_member_limit,r.limit_period,r.sale_starts_at,r.sale_ends_at FROM rewards r
      LEFT JOIN ranks k ON k.id=r.min_rank_id AND k.tenant_id=r.tenant_id WHERE r.id=$1 FOR UPDATE OF r`,
      [id],
    );
  }

  async memberRewardCount(memberId: string, rewardId: string, start: Date | null, end: Date | null) {
    return (
      (await sql.scalar<number>(
        `SELECT count(*)::int FROM redemptions WHERE member_id=$1 AND reward_id=$2
      AND status IN ('PENDING_PICKUP','DELIVERED') AND ($3::timestamptz IS NULL OR requested_at >= $3)
      AND ($4::timestamptz IS NULL OR requested_at < $4)`,
        [memberId, rewardId, start, end],
      )) ?? 0
    );
  }

  async create(input: {
    id: string;
    code: string;
    memberId: string;
    rewardId: string;
    pickupBranchId: string;
    marksCost: number;
    key: string;
    at: Date;
  }) {
    return (await sql.one<RedemptionView>(
      `INSERT INTO redemptions
      (id,tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key,requested_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING ${orderColumns}`,
      [
        input.id,
        db.currentTenantId(),
        input.code,
        input.memberId,
        input.rewardId,
        input.pickupBranchId,
        input.marksCost,
        input.key,
        input.at,
      ],
    ))!;
  }

  consumeStock(rewardId: string) {
    return sql.exec('UPDATE rewards SET stock=stock-1,updated_at=now() WHERE id=$1 AND stock>0', [rewardId]);
  }

  inventoryOut(rewardId: string, redemptionId: string, memberId: string) {
    return sql.exec(
      `INSERT INTO inventory_movements (tenant_id,reward_id,movement_type,quantity,redemption_id,actor_id,reason)
      VALUES ($1,$2,'OUT',1,$3,$4,'Stock allocated to pending redemption')`,
      [db.currentTenantId(), rewardId, redemptionId, memberId],
    );
  }
}
