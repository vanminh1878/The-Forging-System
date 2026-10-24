import { Router } from 'express';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role } from '../../shared/roles';
import type { RedemptionService } from './redemption.service';
import { createRedemptionBody } from './redemption.validation';

export function redemptionRoutes(service: RedemptionService): Router {
  const r = Router();
  r.post('/armory/redemptions', requireAuth, requireRoles(Role.MEMBER), validate({ body: createRedemptionBody }), handle(async (req) => {
    const result = await service.create(authOf(req).userId, req.body);
    return result.duplicate ? ok(result) : created(result);
  }));
  return r;
}
