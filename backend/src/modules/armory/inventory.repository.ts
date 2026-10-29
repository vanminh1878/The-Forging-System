import { db } from '../../db/database';
import { sql } from '../../db/sql';

export interface InventoryFilter {
  rewardId?: string;
  movementType?: 'IN' | 'OUT';
  actorId?: string;
  from?: string;
  to?: string;
}

export class InventoryRepository {
  lockReward(id: string) {
    return sql.one<{ id: string; name: string; stock: number }>(
      'SELECT id,name,stock FROM rewards WHERE id=$1 FOR UPDATE', [id]);
  }

  async setStock(id: string, stock: number) {
    return sql.exec('UPDATE rewards SET stock=$2,updated_at=now() WHERE id=$1', [id, stock]);
  }

  async insert(input: { rewardId: string; movementType: 'IN' | 'OUT'; quantity: number; actorId: string; reason: string }) {
    return (await sql.one(`INSERT INTO inventory_movements (tenant_id,reward_id,movement_type,quantity,actor_id,reason)
      VALUES ($1,$2,$3,$4,$5,$6) RETURNING id,reward_id,movement_type,quantity,redemption_id,actor_id,reason,created_at`,
    [db.currentTenantId(), input.rewardId, input.movementType, input.quantity, input.actorId, input.reason]))!;
  }

  async history(filter: InventoryFilter, limit: number, offset: number) {
    const params = [filter.rewardId ?? null, filter.movementType ?? null, filter.actorId ?? null, filter.from ?? null, filter.to ?? null];
    const where = `($1::uuid IS NULL OR i.reward_id=$1) AND ($2::text IS NULL OR i.movement_type=$2)
      AND ($3::uuid IS NULL OR i.actor_id=$3) AND ($4::timestamptz IS NULL OR i.created_at >= $4)
      AND ($5::timestamptz IS NULL OR i.created_at <= $5)`;
    const items = await sql.many(`SELECT i.id,i.reward_id,r.sku AS reward_sku,r.name AS reward_name,
      i.movement_type,i.quantity,i.redemption_id,i.actor_id,u.full_name AS actor_name,i.reason,i.created_at
      FROM inventory_movements i JOIN rewards r ON r.id=i.reward_id AND r.tenant_id=i.tenant_id
      LEFT JOIN users u ON u.id=i.actor_id AND u.tenant_id=i.tenant_id
      WHERE ${where} ORDER BY i.created_at DESC,i.id DESC LIMIT $6 OFFSET $7`, [...params,limit,offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM inventory_movements i WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }
}
