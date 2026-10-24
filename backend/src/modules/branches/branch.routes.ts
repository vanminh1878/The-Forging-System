import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import type { BranchService } from './branch.service';

const listQuery = z.object({ includeInactive: z.enum(['true', 'false']).default('false') });
const idParam = z.object({ branchId: z.string().uuid() });

export function branchRoutes(service: BranchService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get(
    '/branches',
    validate({ query: listQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof listQuery>;
      return ok(await service.list(authOf(req).roles, q.includeInactive === 'true'));
    }),
  );
  r.get(
    '/branches/:branchId',
    validate({ params: idParam }),
    handle(async (req) => ok(await service.get(req.params.branchId, authOf(req).roles))),
  );
  return r;
}
