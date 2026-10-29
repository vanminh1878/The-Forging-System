import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import { SCHEDULE_STATUSES } from './schedule.rules';
import type { ScheduleService } from './schedule.service';

const realDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((v) => {
    const d = new Date(`${v}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().startsWith(v);
  }, 'invalid calendar date');
const scheduleQuery = z.object({
  view: z.enum(['week', 'month']).default('week'),
  date: realDate.optional(),
  branchId: z.string().uuid().optional(),
  status: z.enum(SCHEDULE_STATUSES as [string, ...string[]]).optional(),
});
const coachSessionsQuery = z.object({ view: z.enum(['day', 'week']).default('day'), date: realDate.optional() });
const rosterQuery = z.object({ filter: z.enum(['all', 'pending', 'reviewed']).default('all') });
const sessionParam = z.object({ sessionId: z.string().uuid() });

/** Learner schedule (CLS-04): sessions of the classes the learner is enrolled in plus any he has attended. */
export function scheduleRoutes(service: ScheduleService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get(
    '/me/schedule',
    requireRoles(Role.MEMBER),
    validate({ query: scheduleQuery }),
    handle(async (req) => {
      const { items, meta } = await service.list(
        authOf(req).userId,
        req.query as unknown as Parameters<ScheduleService['list']>[1],
      );
      return ok(items, meta);
    }),
  );
  r.get(
    '/me/sessions/:sessionId',
    requireRoles(Role.MEMBER),
    validate({ params: sessionParam }),
    handle(async (req) => ok(await service.detail(authOf(req).userId, req.params.sessionId))),
  );

  // Coach API (CLS-05): always limited to sessions where the coach is the session's coach.
  r.get(
    '/coach/classes',
    requireRoles(...RoleGroup.COACHES),
    handle(async (req) => ok(await service.coachClasses(authOf(req).userId))),
  );
  r.get(
    '/coach/sessions',
    requireRoles(...RoleGroup.COACHES),
    validate({ query: coachSessionsQuery }),
    handle(async (req) => {
      const { items, meta } = await service.coachSessions(
        authOf(req).userId,
        req.query as unknown as Parameters<ScheduleService['coachSessions']>[1],
      );
      return ok(items, meta);
    }),
  );
  r.get(
    '/coach/sessions/:id/roster',
    requireRoles(...RoleGroup.COACHES),
    validate({ params: z.object({ id: z.string().uuid() }), query: rosterQuery }),
    handle(async (req) => {
      const { items, meta } = await service.coachRoster(
        authOf(req).userId,
        req.params.id,
        (req.query as unknown as z.infer<typeof rosterQuery>).filter,
      );
      return ok(items, meta);
    }),
  );
  return r;
}
