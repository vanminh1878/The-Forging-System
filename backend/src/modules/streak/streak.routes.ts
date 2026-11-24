import { Router } from 'express';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { Role } from '../../shared/roles';
import type { StreakService } from './streak.service';

export function streakRoutes(service: StreakService): Router {
  const r = Router();
  r.get(
    '/me/streak',
    requireAuth,
    requireRoles(Role.MEMBER),
    handle(async (req) => ok(await service.summary(authOf(req).userId))),
  );
  return r;
}
