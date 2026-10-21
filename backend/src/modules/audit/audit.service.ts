import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { AuditFilter } from './audit.validation';

export interface AuditLogView {
  id: number;
  action: string;
  entityType: string;
  entityId: string;
  beforeData: unknown;
  afterData: unknown;
  reason: string | null;
  actorType: 'USER' | 'SYSTEM';
  actorId: string | null;
  actorName: string | null;
  createdAt: Date;
}

export interface AuditEntry {
  /** Acting user; null means the system (batch job, trigger). */
  actorId: string | null;
  action: string;
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  reason?: string | null;
  ipAddress?: string | null;
}

/** Writes the append-only audit trail (audit_logs). */
export class AuditService {
  async list(filter: AuditFilter, limit: number, offset: number) {
    const params = [filter.action ?? null, filter.entityType ?? null, filter.entityId ?? null,
      filter.actorId ?? null, filter.actorType ?? null, filter.from ?? null, filter.to ?? null,
      filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null];
    const from = `audit_logs a LEFT JOIN users u ON u.id=a.actor_id AND u.tenant_id=a.tenant_id`;
    const where = `($1::text IS NULL OR a.action=$1) AND ($2::text IS NULL OR a.entity_type=$2)
      AND ($3::text IS NULL OR a.entity_id=$3) AND ($4::uuid IS NULL OR a.actor_id=$4)
      AND ($5::text IS NULL OR a.actor_type=$5) AND ($6::timestamptz IS NULL OR a.created_at >= $6)
      AND ($7::timestamptz IS NULL OR a.created_at <= $7)
      AND ($8::text IS NULL OR a.action ILIKE $8 OR a.entity_type ILIKE $8 OR a.entity_id ILIKE $8 OR a.reason ILIKE $8 OR u.full_name ILIKE $8)`;
    const items = await sql.many<AuditLogView>(`SELECT a.id,a.action,a.entity_type,a.entity_id,a.before_data,a.after_data,
      a.reason,a.actor_type,a.created_at,a.actor_id,u.full_name AS actor_name FROM ${from} WHERE ${where}
      ORDER BY a.created_at DESC,a.id DESC LIMIT $9 OFFSET $10`, [...params, limit, offset]);
    const total = await sql.scalar<number>(`SELECT count(*)::int FROM ${from} WHERE ${where}`, params);
    return { items, total: total ?? 0 };
  }

  async record(entry: AuditEntry): Promise<void> {
    await sql.exec(
      `INSERT INTO audit_logs (tenant_id, actor_id, actor_type, action, entity_type, entity_id, before_data, after_data, reason, ip_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb, $9, $10)`,
      [
        db.currentTenantId(),
        entry.actorId,
        entry.actorId ? 'USER' : 'SYSTEM',
        entry.action,
        entry.entityType,
        entry.entityId,
        entry.before === undefined ? null : JSON.stringify(entry.before),
        entry.after === undefined ? null : JSON.stringify(entry.after),
        entry.reason ?? null,
        entry.ipAddress ?? null,
      ],
    );
  }
}
