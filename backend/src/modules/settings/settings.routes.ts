import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, noContent, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { SettingsService } from './settings.service';

const keyParam = z.object({ key: z.string().min(2).max(80) });
const valueBody = z.object({
  value: z.union([z.number(), z.boolean(), z.string(), z.record(z.unknown()), z.array(z.unknown())]),
  reason: z.string().trim().min(3).max(500),
});
const rollbackBody = z.object({
  auditId: z.number().int().positive(),
  reason: z.string().trim().min(3).max(500),
});

/** Admin configuration of points, streak, challenge, armory and lifecycle parameters (ADM-02..06). */
export function settingsRoutes(service: SettingsService): Router {
  const r = Router();
  r.use('/admin/settings', requireAuth, requireRoles(...RoleGroup.ADMINS));
  r.get(
    '/admin/settings',
    handle(async () => ok(await service.listAll())),
  );
  r.put(
    '/admin/settings/:key',
    validate({ params: keyParam, body: valueBody }),
    handle(async (req) => {
      await service.set(req.params.key, req.body.value, authOf(req).userId, req.body.reason);
      return noContent();
    }),
  );
  r.post(
    '/admin/settings/:key/rollback',
    validate({ params: keyParam, body: rollbackBody }),
    handle(async (req) => {
      await service.rollback(req.params.key, req.body.auditId, authOf(req).userId, req.body.reason);
      return noContent();
    }),
  );
  return r;
}
