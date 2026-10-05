import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, noContent, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { SettingsService } from './settings.service';

const keyParam = z.object({ key: z.string().min(2).max(80) });
const valueBody = z.object({ value: z.union([z.number(), z.boolean(), z.string(), z.record(z.unknown()), z.array(z.unknown())]) });

/** Admin configuration of points, streak, challenge, armory and lifecycle parameters (ADM-02..06). */
export function settingsRoutes(service: SettingsService): Router {
  const r = Router();
  r.use('/admin', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get('/admin/settings', handle(async () => ok(await service.listAll())));
  r.put('/admin/settings/:key', validate({ params: keyParam, body: valueBody }), handle(async (req) => {
    await service.set(req.params.key, req.body.value, authOf(req).userId);
    return noContent();
  }));
  return r;
}
