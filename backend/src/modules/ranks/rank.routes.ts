import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { UserDirectory } from '../members/user-directory';
import type { RankService } from './rank.service';

const decisionBody = z.object({ result: z.enum(['PASS', 'FAIL']), note: z.string().trim().max(500).optional() });
const idParam = z.object({ id: z.string().uuid() });
const queueQuery = z.object({ status: z.enum(['OPEN', 'ALL']).default('OPEN') });

/** Rank progression: learner views (/me/...) and the examiner queue (/rank-trials). */
export function rankRoutes(service: RankService, directory: UserDirectory): Router {
  const r = Router();
  r.use(requireAuth);

  // ---- learner ----
  r.get('/me/rank', requireRoles(Role.MEMBER), handle(async (req) => ok(await service.progressFor(authOf(req).userId))));
  r.get('/me/badges', requireRoles(Role.MEMBER), handle(async (req) => ok(await service.badges(authOf(req).userId))));
  r.get('/me/rank-history', requireRoles(Role.MEMBER), handle(async (req) => ok(await service.history(authOf(req).userId))));
  r.get('/me/rank-trials', requireRoles(Role.MEMBER), handle(async (req) => ok(await service.listTrials({ memberId: authOf(req).userId }))));
  r.post('/me/rank-trials', requireRoles(Role.MEMBER), handle(async (req) => created(await service.requestTrial(authOf(req).userId))));
  r.get('/ranks', handle(async () => ok(await service.listRanks())));

  // ---- examiners (coach / head coach / admin) ----
  r.get(
    '/rank-trials',
    requireRoles(...RoleGroup.COACHING_STAFF),
    validate({ query: queueQuery }),
    handle(async (req) => {
      const { roles } = authOf(req);
      const status = (req.query as unknown as { status: string }).status === 'OPEN' ? ['PENDING', 'SCHEDULED'] : undefined;
      return ok(await service.listTrials({ status, approverRoles: service.approverRolesVisibleTo(roles) }, 100));
    }),
  );
  r.post(
    '/rank-trials/:id/decision',
    requireRoles(...RoleGroup.COACHING_STAFF),
    validate({ params: idParam, body: decisionBody }),
    handle(async (req) => {
      const auth = authOf(req);
      const out = await service.decideTrial({
        trialId: req.params.id,
        result: req.body.result,
        note: req.body.note,
        by: auth.userId,
        byName: await directory.actorLabel(auth.userId, auth.roles),
        roles: auth.roles,
      });
      return ok(out);
    }),
  );
  return r;
}
