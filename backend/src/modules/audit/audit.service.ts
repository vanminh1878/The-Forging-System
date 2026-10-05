import { db } from '../../db/database';
import { sql } from '../../db/sql';

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
