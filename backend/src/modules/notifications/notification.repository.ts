import { db } from '../../db/database';
import { sql } from '../../db/sql';

export interface NotificationRow {
  id: string;
  userId: string | null;
  branchId: string | null;
  rankId: string | null;
  eventType: string;
  title: string;
  body: string;
  payload: unknown;
  readAt: Date | null;
  createdAt: Date;
  sentBy: string | null;
  isRead: boolean;
}

export interface StaffNotificationRow {
  id: number;
  toRole: string;
  eventType: string;
  title: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
}

export interface TemplateRow {
  id: string;
  eventType: string;
  title: string;
  body: string;
  channels: string[];
  sendTime: string | null;
  isEnabled: boolean;
  dedupePeriod: string;
}

export class NotificationRepository {
  /** Inserts a personal notification. Returns the id, or null when `dedupeKey` was already used. */
  async insertPersonal(input: {
    userId: string;
    event: string;
    title: string;
    body: string;
    payload?: unknown;
    dedupeKey?: string | null;
    templateId?: string | null;
  }): Promise<string | null> {
    const row = await sql.one<{ id: string }>(
      `INSERT INTO notifications (tenant_id, user_id, template_id, event_type, title, body, payload, dedupe_key)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8)
       ON CONFLICT (dedupe_key) DO NOTHING
       RETURNING id`,
      [
        db.currentTenantId(),
        input.userId,
        input.templateId ?? null,
        input.event,
        input.title,
        input.body,
        input.payload === undefined ? null : JSON.stringify(input.payload),
        input.dedupeKey ? `${db.currentTenantId()}:${input.dedupeKey}` : null,
      ],
    );
    return row?.id ?? null;
  }

  async insertBroadcast(input: {
    title: string;
    body: string;
    branchId: string | null;
    rankId: string | null;
    sentBy: string;
  }): Promise<string> {
    const row = await sql.one<{ id: string }>(
      `INSERT INTO notifications (tenant_id, user_id, branch_id, rank_id, sent_by, event_type, title, body)
       VALUES ($1, NULL, $2, $3, $4, 'BROADCAST', $5, $6) RETURNING id`,
      [db.currentTenantId(), input.branchId, input.rankId, input.sentBy, input.title, input.body],
    );
    return row!.id;
  }

  insertStaff(toRole: string, event: string, title: string, body: string): Promise<number> {
    return sql.exec(
      `INSERT INTO staff_notifications (tenant_id, to_role, event_type, title, body) VALUES ($1, $2, $3, $4, $5)`,
      [db.currentTenantId(), toRole, event, title, body],
    );
  }

  /** Personal notifications plus broadcasts that target this member (branch / rank / everyone). */
  listForMember(userId: string, limit: number, offset: number): Promise<NotificationRow[]> {
    return sql.many<NotificationRow>(
      `SELECT n.*, (n.read_at IS NOT NULL OR r.user_id IS NOT NULL) AS is_read
         FROM notifications n
         JOIN members m ON m.user_id = $1
         LEFT JOIN notification_reads r ON r.notification_id = n.id AND r.user_id = $1
        WHERE n.user_id = $1
           OR (n.user_id IS NULL AND n.event_type = 'BROADCAST'
               AND (n.branch_id IS NULL OR n.branch_id = m.home_branch_id)
               AND (n.rank_id IS NULL OR n.rank_id = m.current_rank_id))
        ORDER BY n.created_at DESC
        LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );
  }

  async countUnreadForMember(userId: string): Promise<number> {
    const n = await sql.scalar<number>(
      `SELECT count(*) FROM notifications n
         JOIN members m ON m.user_id = $1
         LEFT JOIN notification_reads r ON r.notification_id = n.id AND r.user_id = $1
        WHERE n.read_at IS NULL AND r.user_id IS NULL
          AND (n.user_id = $1
            OR (n.user_id IS NULL AND n.event_type = 'BROADCAST'
                AND (n.branch_id IS NULL OR n.branch_id = m.home_branch_id)
                AND (n.rank_id IS NULL OR n.rank_id = m.current_rank_id)))`,
      [userId],
    );
    return n ?? 0;
  }

  async markAllReadForMember(userId: string): Promise<void> {
    await sql.exec(`UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`, [userId]);
    await sql.exec(
      `INSERT INTO notification_reads (notification_id, user_id, tenant_id)
       SELECT n.id, $1, $2 FROM notifications n JOIN members m ON m.user_id = $1
        WHERE n.user_id IS NULL AND n.event_type = 'BROADCAST'
          AND (n.branch_id IS NULL OR n.branch_id = m.home_branch_id)
          AND (n.rank_id IS NULL OR n.rank_id = m.current_rank_id)
       ON CONFLICT DO NOTHING`,
      [userId, db.currentTenantId()],
    );
  }

  async markOneReadForMember(userId: string, notificationId: string): Promise<void> {
    const updated = await sql.exec(
      `UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 AND read_at IS NULL`,
      [notificationId, userId],
    );
    if (updated === 0) {
      await sql.exec(
        `INSERT INTO notification_reads (notification_id, user_id, tenant_id)
         SELECT id, $2, $3 FROM notifications WHERE id = $1 AND user_id IS NULL
         ON CONFLICT DO NOTHING`,
        [notificationId, userId, db.currentTenantId()],
      );
    }
  }

  listStaff(roles: string[], limit: number): Promise<StaffNotificationRow[]> {
    return sql.many<StaffNotificationRow>(
      `SELECT * FROM staff_notifications WHERE to_role = ANY($1::text[]) ORDER BY created_at DESC LIMIT $2`,
      [roles, limit],
    );
  }

  async countUnreadStaff(roles: string[]): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*) FROM staff_notifications WHERE to_role = ANY($1::text[]) AND read_at IS NULL`,
        [roles],
      )) ?? 0
    );
  }

  markStaffRead(roles: string[]): Promise<number> {
    return sql.exec(
      `UPDATE staff_notifications SET read_at = now() WHERE to_role = ANY($1::text[]) AND read_at IS NULL`,
      [roles],
    );
  }

  findTemplate(event: string): Promise<TemplateRow | null> {
    return sql.one<TemplateRow>(`SELECT * FROM notification_templates WHERE event_type = $1`, [event]);
  }

  listTemplates(): Promise<TemplateRow[]> {
    return sql.many<TemplateRow>(`SELECT * FROM notification_templates ORDER BY event_type`);
  }

  upsertTemplate(input: { event: string; title: string; body: string; isEnabled: boolean; updatedBy: string }) {
    return sql.exec(
      `INSERT INTO notification_templates (tenant_id, event_type, title, body, is_enabled, updated_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (tenant_id, event_type) DO UPDATE
         SET title = EXCLUDED.title, body = EXCLUDED.body, is_enabled = EXCLUDED.is_enabled,
             updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [db.currentTenantId(), input.event, input.title, input.body, input.isEnabled, input.updatedBy],
    );
  }

  /** Valid push tokens of one user. */
  async tokensForUser(userId: string): Promise<{ id: string; token: string }[]> {
    return sql.many(`SELECT id, token FROM device_tokens WHERE user_id = $1 AND is_valid = true`, [userId]);
  }

  /** Valid push tokens of every non-inactive member targeted by a broadcast. */
  async tokensForBroadcast(branchId: string | null, rankId: string | null): Promise<{ id: string; token: string; userId: string }[]> {
    return sql.many(
      `SELECT d.id, d.token, d.user_id FROM device_tokens d JOIN members m ON m.user_id = d.user_id
        WHERE d.is_valid = true AND m.status <> 'INACTIVE'
          AND ($1::uuid IS NULL OR m.home_branch_id = $1)
          AND ($2::uuid IS NULL OR m.current_rank_id = $2)`,
      [branchId, rankId],
    );
  }

  async countBroadcastAudience(branchId: string | null, rankId: string | null): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*) FROM members m
          WHERE m.status <> 'INACTIVE' AND m.duplicate_of_member_id IS NULL
            AND ($1::uuid IS NULL OR m.home_branch_id = $1)
            AND ($2::uuid IS NULL OR m.current_rank_id = $2)`,
        [branchId, rankId],
      )) ?? 0
    );
  }

  invalidateTokens(tokens: string[]): Promise<number> {
    return sql.exec(`UPDATE device_tokens SET is_valid = false WHERE token = ANY($1::text[])`, [tokens]);
  }

  logDelivery(input: { notificationId: string | null; userId: string | null; event: string; status: 'SENT' | 'FAILED' | 'SKIPPED'; skipReason?: string; error?: string }) {
    return sql.exec(
      `INSERT INTO notification_logs (tenant_id, notification_id, user_id, event_type, channel, status, skip_reason, error_message, sent_at)
       VALUES ($1, $2, $3, $4, 'PUSH', $5, $6, $7, CASE WHEN $5 = 'SENT' THEN now() END)`,
      [db.currentTenantId(), input.notificationId, input.userId, input.event, input.status, input.skipReason ?? null, input.error ?? null],
    );
  }
}
