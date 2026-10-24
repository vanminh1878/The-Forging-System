import { Router } from 'express';
import type { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { AdminArmoryService } from './admin-armory.service';
import { adminRewardQuery, createRewardBody, createTierBody, rewardParam, tierParam, updateRewardBody, updateTierBody } from './admin-armory.validation';

export function adminArmoryRoutes(service: AdminArmoryService): Router {
  const r = Router();
  r.use('/admin/armory', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/armory/tiers', handle(async () => ok(await service.tiers())));
  r.get('/admin/armory/tiers/:tierCode', validate({ params: tierParam }), handle(async (req) => ok(await service.tier(req.params.tierCode))));
  r.post('/admin/armory/tiers', validate({ body: createTierBody }), handle(async (req) => created(await service.createTier(req.body, authOf(req).userId))));
  r.patch('/admin/armory/tiers/:tierCode', validate({ params: tierParam, body: updateTierBody }), handle(async (req) => ok(await service.updateTier(req.params.tierCode, req.body, authOf(req).userId))));
  r.get('/admin/armory/rewards', validate({ query: adminRewardQuery }), handle(async (req) => {
    const query = req.query as unknown as z.infer<typeof adminRewardQuery>;
    const page = toPage(query);
    const result = await service.search(query, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  r.get('/admin/armory/rewards/:rewardId', validate({ params: rewardParam }), handle(async (req) => ok(await service.reward(req.params.rewardId))));
  r.post('/admin/armory/rewards', validate({ body: createRewardBody }), handle(async (req) => created(await service.createReward(req.body, authOf(req).userId))));
  r.patch('/admin/armory/rewards/:rewardId', validate({ params: rewardParam, body: updateRewardBody }), handle(async (req) => ok(await service.updateReward(req.params.rewardId, req.body, authOf(req).userId))));
  return r;
}
