import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, noContent, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { NotificationService } from './notification.service';

const idParam = z.object({ id: z.string().uuid() });
const broadcastBody = z.object({
  scope: z.enum(['all', 'branch', 'rank']),
  branchId: z.string().uuid().optional(),
  rankId: z.string().uuid().optional(),
  title: z.string().trim().min(2).max(120),
  body: z.string().trim().min(2).max(1000),
});
const templateBody = z.object({
  title: z.string().trim().min(2).max(120),
  body: z.string().trim().min(2).max(1000),
  isEnabled: z.boolean(),
});
const eventParam = z.object({ event: z.string().min(2).max(60) });

export function notificationRoutes(service: NotificationService): Router {
  const r = Router();
  r.use(requireAuth);

  // ---- learner inbox (HV-06) ----
  r.get('/me/notifications', requireRoles(Role.MEMBER), validate({ query: paginationQuery }), handle(async (req) => {
    const page = toPage(req.query as unknown as { page: number; limit: number });
    const { items, unread } = await service.listForMember(authOf(req).userId, page.limit, page.offset);
    return ok(items, { ...pageMeta(page, items.length), unread });
  }));
  r.get('/me/notifications/unread-count', requireRoles(Role.MEMBER), handle(async (req) =>
    ok({ unread: await service.unreadCountForMember(authOf(req).userId) }),
  ));
  r.post('/me/notifications/read-all', requireRoles(Role.MEMBER), handle(async (req) => {
    await service.markAllReadForMember(authOf(req).userId);
    return noContent();
  }));
  r.post('/me/notifications/:id/read', requireRoles(Role.MEMBER), validate({ params: idParam }), handle(async (req) => {
    await service.markOneReadForMember(authOf(req).userId, req.params.id);
    return noContent();
  }));

  // ---- staff inbox (per role) ----
  r.get('/staff/notifications', requireRoles(...RoleGroup.STAFF), handle(async (req) => {
    const { items, unread } = await service.listForStaff(authOf(req).roles, 50);
    return ok(items, { unread });
  }));
  r.post('/staff/notifications/read-all', requireRoles(...RoleGroup.STAFF), handle(async (req) => {
    await service.markStaffRead(authOf(req).roles);
    return noContent();
  }));

  // ---- admin: broadcast + templates (ADM-07) ----
  r.post('/admin/notifications/broadcast', requireRoles(...RoleGroup.ADMINS), validate({ body: broadcastBody }), handle(async (req) =>
    ok(await service.sendBroadcast({ ...req.body, sentBy: authOf(req).userId })),
  ));
  r.get('/admin/notifications/templates', requireRoles(...RoleGroup.ADMINS), handle(async () => ok(await service.listTemplates())));
  r.put('/admin/notifications/templates/:event', requireRoles(...RoleGroup.ADMINS), validate({ params: eventParam, body: templateBody }), handle(async (req) => {
    await service.upsertTemplate({ event: req.params.event, ...req.body, updatedBy: authOf(req).userId });
    return noContent();
  }));
  return r;
}
