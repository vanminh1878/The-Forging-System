import { Router } from 'express';
import { z } from 'zod';
import { handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role } from '../../shared/roles';
import type { ArmoryService } from './armory.service';

export const rewardSearchQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  tierCode: z.string().trim().min(1).max(100).optional(),
});

export function armoryRoutes(service: ArmoryService): Router {
  const r = Router();
  r.use('/armory', requireAuth, requireRoles(Role.MEMBER));
  r.get('/armory/tiers', handle(async () => ok(await service.tiers())));
  r.get('/armory/rewards', validate({ query: rewardSearchQuery }), handle(async (req) => {
    const query = req.query as unknown as z.infer<typeof rewardSearchQuery>;
    const page = toPage(query);
    const result = await service.rewards(query, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  return r;
}
