import { Router } from 'express';
import { authOf, handle, noContent, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { SettingsService } from './settings.service';
import { z } from 'zod';
import { settingsKeyParam, settingsQuery, settingsValueBody } from './settings.validation';

const rollbackBody = z.object({
  auditLogId: z.number().int().positive().optional(),
  versionId: z.number().int().positive().optional(),
  auditId: z.number().int().positive().optional(),
  reason: z.string().trim().min(3).max(500),
}).strict().refine((b) => !!(b.auditLogId || b.versionId || b.auditId), {
  message: 'Can chon phien ban cau hinh de hoan tac.',
});

/** Admin configuration of points, streak, challenge, armory and lifecycle parameters (ADM-02..06). */
export function settingsRoutes(service: SettingsService): Router {
  const r = Router();
  r.use('/admin', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/settings', validate({ query: settingsQuery }), handle(async (req) => ok(await service.listAll(req.query as z.infer<typeof settingsQuery>))));
  r.get('/admin/settings/:key', validate({ params: settingsKeyParam }), handle(async (req) => ok(await service.entry(req.params.key))));
  r.put('/admin/settings/:key', validate({ params: settingsKeyParam, body: settingsValueBody }), handle(async (req) => {
    await service.set(req.params.key, req.body.value, authOf(req).userId, req.body.reason);
    return noContent();
  }));
  r.get('/admin/settings/:key/history', validate({ params: settingsKeyParam }), handle(async (req) => ok(await service.history(req.params.key))));
  r.get('/admin/settings/:key/versions', validate({ params: settingsKeyParam }), handle(async (req) => ok(await service.history(req.params.key))));
  r.post('/admin/settings/:key/rollback', validate({ params: settingsKeyParam, body: rollbackBody }), handle(async (req) => {
    const versionId = req.body.auditLogId ?? req.body.versionId ?? req.body.auditId;
    await service.rollback(req.params.key, versionId, authOf(req).userId, req.body.reason);
    return noContent();
  }));
  return r;
}
