import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { ClassService } from './class.service';

const idParam = z.object({ id: z.string().uuid() });
const enrollmentParam = idParam.extend({ memberId: z.string().uuid() });
const boolString = z.enum(['true', 'false']).transform((v) => v === 'true');
const listQuery = paginationQuery.extend({
  branchId: z.string().uuid().optional(),
  sessionTypeCode: z.string().min(1).max(30).optional(),
  isActive: boolString.optional(),
});
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const classFields = {
  branchId: z.string().uuid(),
  name: z.string().trim().min(1).max(120),
  sessionTypeCode: z.string().min(1).max(30),
  courseId: z.string().uuid().nullable(),
  defaultCoachId: z.string().uuid().nullable(),
  weekdays: z
    .array(z.number().int().min(1).max(7))
    .min(1)
    .refine((a) => new Set(a).size === a.length, 'weekdays must be unique'),
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'HH:mm'),
  durationMinutes: z.number().int().min(1).max(1440),
  capacity: z.number().int().min(1).max(1000).nullable(),
  isActive: z.boolean(),
};
const createBody = z.object({
  ...classFields,
  courseId: classFields.courseId.default(null),
  defaultCoachId: classFields.defaultCoachId.default(null),
  capacity: classFields.capacity.default(null),
  isActive: classFields.isActive.default(true),
});
const patchBody = z
  .object(classFields)
  .partial()
  .refine((b) => Object.keys(b).length > 0, 'at least one field is required');
const enrollBody = z.object({
  memberId: z.string().uuid(),
  startDate: date.optional(),
  endDate: date.nullable().optional(),
  membershipId: z.string().uuid().nullable().optional(),
});
const unenrollBody = z.object({ reason: z.string().trim().min(1).max(500).optional() }).default({});

const isoInstant = z.string().datetime({ offset: true }).transform((v) => new Date(v));
const uuid = z.string().uuid();
const sessionBody = z.object({
  sessionTypeCode: z.string().min(1).max(30),
  branchId: uuid,
  startsAt: isoInstant,
  durationMinutes: z.number().int().min(15).max(480),
  title: z.string().trim().min(1).max(200),
  coachId: uuid.optional(),
  classId: uuid.optional(),
  lessonPlanId: uuid.optional(),
  isExam: z.boolean().optional(),
  capacity: z.number().int().min(1).max(1000).optional(),
  maxDpOverride: z.number().int().min(0).max(10000).optional(),
  notes: z.string().trim().max(1000).optional(),
  memberIds: z.array(uuid).max(50).optional(),
});
const examBody = z.object({
  date: date.refine((v) => new Date(`${v}T00:00:00Z`).toISOString().startsWith(v), 'invalid calendar date'),
  title: z.string().trim().min(1).max(200).optional(),
  lessonPlanId: uuid.optional(),
});
// The reason is checked in the service so that a missing one answers CANCEL_REASON_REQUIRED.
const cancelBody = z.object({ reason: z.string().max(500).optional() }).default({});

const sessionsQuery = z.object({ from: date.optional(), to: date.optional() });

export function classRoutes(service: ClassService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get(
    '/admin/classes',
    requireRoles(...RoleGroup.STAFF),
    validate({ query: listQuery }),
    handle(async (req) => {
      const { page, limit, ...filter } = req.query as unknown as z.infer<typeof listQuery>;
      const p = toPage({ page, limit });
      const { rows, total } = await service.list(filter, p.limit, p.offset);
      return ok(rows, pageMeta(p, total));
    }),
  );
  r.get(
    '/admin/classes/:id',
    requireRoles(...RoleGroup.STAFF),
    validate({ params: idParam }),
    handle(async (req) => ok(await service.get(req.params.id))),
  );
  r.get(
    '/admin/classes/:id/sessions',
    requireRoles(...RoleGroup.STAFF),
    validate({ params: idParam, query: sessionsQuery }),
    handle(async (req) => {
      const { from, to } = req.query as unknown as z.infer<typeof sessionsQuery>;
      return ok(await service.listSessions(req.params.id, from, to));
    }),
  );
  r.post(
    '/admin/classes',
    requireRoles(...RoleGroup.ADMINS),
    validate({ body: createBody }),
    handle(async (req) => created(await service.create(req.body, authOf(req).userId))),
  );
  r.patch(
    '/admin/classes/:id',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: idParam, body: patchBody }),
    handle(async (req) => ok(await service.update(req.params.id, req.body, authOf(req).userId))),
  );
  r.post(
    '/admin/classes/:id/enrollments',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: idParam, body: enrollBody }),
    handle(async (req) => created(await service.enroll({ classId: req.params.id, ...req.body, by: authOf(req).userId }))),
  );
  r.delete(
    '/admin/classes/:id/enrollments/:memberId',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: enrollmentParam, body: unenrollBody }),
    handle(async (req) => {
      await service.unenroll(req.params.id, req.params.memberId, authOf(req).userId, req.body.reason);
      return ok({ ended: true });
    }),
  );
  r.post(
    '/sessions',
    requireRoles(...RoleGroup.COACHING_STAFF),
    validate({ body: sessionBody }),
    handle(async (req) => created(await service.createSession(req.body, authOf(req)))),
  );
  r.post(
    '/classes/:id/exam-sessions',
    requireRoles(...RoleGroup.COACHING_STAFF),
    validate({ params: idParam, body: examBody }),
    handle(async (req) => created(await service.createExamSession(req.params.id, req.body, authOf(req)))),
  );
  r.post(
    '/sessions/:id/cancel',
    requireRoles(...RoleGroup.COACHING_STAFF),
    validate({ params: idParam, body: cancelBody }),
    handle(async (req) => ok(await service.cancelSession(req.params.id, req.body.reason, authOf(req)))),
  );
  return r;
}
