import { Router } from 'express';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { RedemptionService } from './redemption.service';
import { cancelBody, createRedemptionBody, decisionBody, redemptionIdParam } from './redemption.validation';

export function redemptionRoutes(service: RedemptionService): Router {
  const r = Router();
  r.post('/armory/redemptions', requireAuth, requireRoles(Role.MEMBER), validate({ body: createRedemptionBody }), handle(async (req) => {
    const result = await service.create(authOf(req).userId, req.body);
    return result.duplicate ? ok(result) : created(result);
  }));
  r.post('/me/armory/redemptions/:redemptionId/cancel', requireAuth, requireRoles(Role.MEMBER),
    validate({ params: redemptionIdParam, body: cancelBody }), handle(async (req) =>
      ok(await service.cancel(authOf(req).userId, req.params.redemptionId, req.body.reason))));
  r.post('/staff/armory/redemptions/:redemptionId/decision', requireAuth, requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: redemptionIdParam, body: decisionBody }), handle(async (req) =>
      ok(await service.decide(req.params.redemptionId, req.body, authOf(req)))));
  return r;
}
