import { Router } from 'express';
import type { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role } from '../../shared/roles';
import type { RedemptionService } from './redemption.service';
import { createRedemptionBody, redemptionHistoryQuery, redemptionIdParam } from './redemption.validation';

export function redemptionRoutes(service: RedemptionService): Router {
  const r = Router();
  r.post('/armory/redemptions', requireAuth, requireRoles(Role.MEMBER), validate({ body: createRedemptionBody }), handle(async (req) => {
    const result = await service.create(authOf(req).userId, req.body);
    return result.duplicate ? ok(result) : created(result);
  }));
  r.get('/me/armory/redemptions', requireAuth, requireRoles(Role.MEMBER), validate({ query: redemptionHistoryQuery }), handle(async (req) => {
    const query = req.query as unknown as z.infer<typeof redemptionHistoryQuery>;
    const page = toPage(query);
    const result = await service.history(authOf(req).userId, { status: query.status }, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  r.get('/me/armory/redemptions/:redemptionId', requireAuth, requireRoles(Role.MEMBER), validate({ params: redemptionIdParam }), handle(async (req) =>
    ok(await service.detail(authOf(req).userId, req.params.redemptionId)),
  ));
  return r;
}
