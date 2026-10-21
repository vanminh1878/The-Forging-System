import { Router } from 'express';
import type { z } from 'zod';
import { handle, ok } from '../../common/http/handler';
import { pageMeta, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { AuditService } from './audit.service';
import { auditQuery } from './audit.validation';

/** Read-only audit trail for admins (ADM-11). */
export function auditRoutes(service: AuditService): Router {
  const r = Router();
  r.use('/admin', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/audit-logs', validate({ query: auditQuery }), handle(async (req) => {
    const q = req.query as unknown as z.infer<typeof auditQuery>;
    const page = toPage(q);
    const result = await service.list(q, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  return r;
}
