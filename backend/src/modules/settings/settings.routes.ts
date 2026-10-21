import { Router } from 'express';
import type { z } from 'zod';
import { authOf, handle, noContent, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { SettingsService } from './settings.service';
import { settingsKeyParam, settingsQuery, settingsValueBody } from './settings.validation';

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
  return r;
}
