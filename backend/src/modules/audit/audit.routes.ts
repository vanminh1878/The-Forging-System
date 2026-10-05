import { Router } from 'express';
import { z } from 'zod';
import { handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { sql } from '../../db/sql';
import { RoleGroup } from '../../shared/roles';

const query = paginationQuery.extend({
  action: z.string().trim().max(60).optional(),
  entityType: z.string().trim().max(60).optional(),
  entityId: z.string().trim().max(80).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

/** Read-only audit trail for admins (ADM-11). */
export function auditRoutes(): Router {
  const r = Router();
  r.use('/admin', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/audit-logs', validate({ query }), handle(async (req) => {
    const q = req.query as unknown as z.infer<typeof query>;
    const page = toPage(q);
    const params = [q.action ?? null, q.entityType ?? null, q.entityId ?? null, q.from ?? null, q.to ?? null];
    const where = `($1::text IS NULL OR a.action = $1) AND ($2::text IS NULL OR a.entity_type = $2)
                   AND ($3::text IS NULL OR a.entity_id = $3) AND ($4::timestamptz IS NULL OR a.created_at >= $4)
                   AND ($5::timestamptz IS NULL OR a.created_at <= $5)`;
    const items = await sql.many(
      `SELECT a.id, a.action, a.entity_type, a.entity_id, a.before_data, a.after_data, a.reason, a.actor_type,
              a.created_at, a.actor_id, u.full_name AS actor_name
         FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_id
        WHERE ${where} ORDER BY a.id DESC LIMIT $6 OFFSET $7`,
      [...params, page.limit, page.offset],
    );
    const total = (await sql.scalar<number>(`SELECT count(*) FROM audit_logs a WHERE ${where}`, params)) ?? 0;
    return ok(items, pageMeta(page, total));
  }));
  return r;
}
