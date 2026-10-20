import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { StaffService } from './staff.service';

export const staffRole = z.enum(['COACH', 'HEAD_COACH', 'RECEPTIONIST', 'ADMIN', 'SUPER_ADMIN']);
const idParam = z.object({ staffId: z.string().uuid() });
const reason = z.string().trim().min(3).max(500);
const searchQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  role: staffRole.optional(),
  branchId: z.string().uuid().optional(),
  status: z.enum(['ACTIVE', 'LOCKED', 'DISABLED']).optional(),
});
const createBody = z.object({
  fullName: z.string().trim().min(2).max(100),
  phone: z.string().trim().min(9).max(16).optional(),
  email: z.string().trim().email().max(254).optional(),
  role: staffRole,
  branchId: z.string().uuid(),
}).strict().refine((input) => input.phone || input.email, { message: 'Cần số điện thoại hoặc email.' });
const patchBody = z.object({ role: staffRole.optional(), branchId: z.string().uuid().optional(), reason }).strict()
  .refine((input) => input.role || input.branchId, { message: 'Cần vai trò hoặc chi nhánh mới.' });

export function staffRoutes(service: StaffService): Router {
  const r = Router();
  r.use('/admin/staff', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/staff', validate({ query: searchQuery }), handle(async (req) => {
    const query = req.query as unknown as z.infer<typeof searchQuery>;
    const page = toPage(query);
    const result = await service.search(query, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  r.get('/admin/staff/:staffId', validate({ params: idParam }), handle(async (req) => ok(await service.get(req.params.staffId))));
  r.post('/admin/staff', validate({ body: createBody }), handle(async (req) => created(await service.create(req.body, authOf(req)))));
  r.patch('/admin/staff/:staffId', validate({ params: idParam, body: patchBody }), handle(async (req) =>
    ok(await service.update(req.params.staffId, req.body, authOf(req))),
  ));
  r.post('/admin/staff/:staffId/status', validate({ params: idParam, body: z.object({ status: z.enum(['ACTIVE', 'DISABLED']), reason }).strict() }), handle(async (req) =>
    ok(await service.setStatus(req.params.staffId, req.body.status, req.body.reason, authOf(req))),
  ));
  r.post('/admin/staff/:staffId/reset-password', validate({ params: idParam, body: z.object({ reason }).strict() }), handle(async (req) =>
    ok(await service.resetPassword(req.params.staffId, req.body.reason, authOf(req))),
  ));
  return r;
}
