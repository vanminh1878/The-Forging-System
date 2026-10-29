import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { BatchService } from './batch.service';

const keyParam = z.object({ key: z.string().min(1).max(30) });
const runsQuery = paginationQuery.extend({
  key: z.string().min(1).max(30).optional(),
  status: z.enum(['SUCCESS', 'FAILED', 'SKIPPED']).optional(),
});

export function batchRoutes(service: BatchService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get(
    '/admin/batch-jobs',
    requireRoles(...RoleGroup.ADMINS),
    handle(async () => ok(await service.listJobs())),
  );
  r.post(
    '/admin/batch-jobs/:key/run',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: keyParam }),
    handle(async (req) => ok(await service.runNow(req.params.key, authOf(req).userId))),
  );
  r.get(
    '/admin/batch-runs',
    requireRoles(...RoleGroup.ADMINS),
    validate({ query: runsQuery }),
    handle(async (req) => {
      const { page, limit, ...filter } = req.query as unknown as z.infer<typeof runsQuery>;
      const p = toPage({ page, limit });
      const { rows, total } = await service.listRuns(filter, p.limit, p.offset);
      return ok(rows, pageMeta(p, total));
    }),
  );
  return r;
}
