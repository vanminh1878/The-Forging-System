import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, noContent, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { MemberService } from './member.service';

const searchQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  status: z.enum(['ACTIVE', 'FROZEN', 'INACTIVE']).optional(),
  branchId: z.string().uuid().optional(),
});
const idParam = z.object({ memberId: z.string().uuid() });
const createBody = z.object({
  fullName: z.string().trim().min(2).max(100),
  phone: z.string().trim().min(9).max(16).optional(),
  email: z.string().trim().email().optional(),
  homeBranchId: z.string().uuid().optional(),
});
const statusBody = z.object({ status: z.enum(['ACTIVE', 'FROZEN', 'INACTIVE']), reason: z.string().trim().min(3).max(500) });
const mergeBody = z.object({ keepId: z.string().uuid(), dropId: z.string().uuid() });
const profilePatch = z.object({
  fullName: z.string().trim().min(2).max(100).optional(),
  avatarUrl: z.string().url().nullable().optional(),
  email: z.string().trim().email().nullable().optional(),
  phone: z.string().trim().min(9).max(16).nullable().optional(),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER']).optional(),
});

export function memberRoutes(service: MemberService): Router {
  const r = Router();
  r.use(requireAuth);

  // ---- learner profile (HV-04) ----
  r.get('/me/profile', requireRoles(Role.MEMBER), handle(async (req) => ok(await service.getProfile(authOf(req).userId))));
  r.patch('/me/profile', requireRoles(Role.MEMBER), validate({ body: profilePatch }), handle(async (req) =>
    ok(await service.updateProfile(authOf(req).userId, req.body)),
  ));

  // ---- front desk / admin: look up before creating (LT-02) ----
  r.get('/members', requireRoles(...RoleGroup.STAFF), validate({ query: searchQuery }), handle(async (req) => {
    const q = req.query as unknown as z.infer<typeof searchQuery>;
    const page = toPage(q);
    const { items, total } = await service.search({ q: q.q, status: q.status, branchId: q.branchId }, page.limit, page.offset);
    return ok(items, pageMeta(page, total));
  }));
  r.get('/members/:memberId', requireRoles(...RoleGroup.STAFF), validate({ params: idParam }), handle(async (req) =>
    ok(await service.getProfile(req.params.memberId)),
  ));
  r.get('/members/:memberId/duplicates', requireRoles(...RoleGroup.FRONT_DESK), validate({ params: idParam }), handle(async (req) =>
    ok(await service.findDuplicates(req.params.memberId)),
  ));
  r.post('/members', requireRoles(...RoleGroup.FRONT_DESK), validate({ body: createBody }), handle(async (req) => {
    const auth = authOf(req);
    return created(await service.createMember({ ...req.body, createdBy: auth.userId }));
  }));
  r.post('/members/:memberId/status', requireRoles(...RoleGroup.FRONT_DESK), validate({ params: idParam, body: statusBody }), handle(async (req) => {
    const auth = authOf(req);
    await service.changeStatus({ memberId: req.params.memberId, ...req.body, by: auth.userId, via: 'MANUAL', actorRoles: auth.roles });
    return noContent();
  }));
  r.post('/admin/members/merge', requireRoles(...RoleGroup.ADMINS), validate({ body: mergeBody }), handle(async (req) => {
    await service.merge({ ...req.body, by: authOf(req).userId });
    return noContent();
  }));
  return r;
}
