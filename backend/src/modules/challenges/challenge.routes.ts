import { Router } from 'express';
import type { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { ChallengeService } from './challenge.service';
import { challengeIdParam, challengeSearchQuery, createChallengeBody, updateChallengeBody } from './challenge.validation';

export function challengeRoutes(service: ChallengeService): Router {
  const r = Router();
  r.use('/admin/challenges', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/challenges', validate({ query: challengeSearchQuery }), handle(async (req) => {
    const filter = req.query as unknown as z.infer<typeof challengeSearchQuery>;
    const page = toPage(filter);
    const result = await service.search(filter, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  r.get('/admin/challenges/:challengeId', validate({ params: challengeIdParam }), handle(async (req) => ok(await service.get(req.params.challengeId))));
  r.post('/admin/challenges', validate({ body: createChallengeBody }), handle(async (req) => created(await service.create(req.body, authOf(req).userId))));
  r.patch('/admin/challenges/:challengeId', validate({ params: challengeIdParam, body: updateChallengeBody }), handle(async (req) =>
    ok(await service.update(req.params.challengeId, req.body, authOf(req).userId)),
  ));
  return r;
}
