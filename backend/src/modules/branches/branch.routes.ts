import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { BranchService } from './branch.service';

const listQuery = z.object({ includeInactive: z.enum(['true', 'false']).default('false') });
const idParam = z.object({ branchId: z.string().uuid() });

const code = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^[A-Z0-9_-]{2,20}$/);
const writable = {
  name: z.string().trim().min(2).max(100),
  address: z.string().trim().max(255).nullable(),
  openingHours: z.string().trim().max(100).nullable(),
  latitude: z.number().min(-90).max(90).nullable(),
  longitude: z.number().min(-180).max(180).nullable(),
  geofenceRadiusM: z.number().int().min(10).max(5000),
};
const createBody = z.object({
  code,
  ...writable,
  address: writable.address.optional(),
  openingHours: writable.openingHours.optional(),
  latitude: writable.latitude.optional(),
  longitude: writable.longitude.optional(),
  geofenceRadiusM: writable.geofenceRadiusM.optional(),
});
const patchBody = z.object({
  code: code.optional(),
  name: writable.name.optional(),
  address: writable.address.optional(),
  openingHours: writable.openingHours.optional(),
  latitude: writable.latitude.optional(),
  longitude: writable.longitude.optional(),
  geofenceRadiusM: writable.geofenceRadiusM.optional(),
});
const rotateBody = z.object({ reason: z.string().trim().min(3).max(500).optional() });
const statusBody = z.object({ isActive: z.boolean(), reason: z.string().trim().min(3).max(500) });

export function branchRoutes(service: BranchService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get(
    '/branches',
    validate({ query: listQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof listQuery>;
      return ok(await service.list(authOf(req).roles, q.includeInactive === 'true'));
    }),
  );
  r.get(
    '/branches/:branchId',
    validate({ params: idParam }),
    handle(async (req) => ok(await service.get(req.params.branchId, authOf(req).roles))),
  );

  r.get(
    '/branches/:branchId/qr',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: idParam }),
    handle(async (req) => ok(await service.getQr(req.params.branchId))),
  );

  // ---- admin ----
  r.post(
    '/admin/branches',
    requireRoles(...RoleGroup.ADMINS),
    validate({ body: createBody }),
    handle(async (req) => created(await service.create(req.body, authOf(req).userId))),
  );
  r.patch(
    '/admin/branches/:branchId',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: idParam, body: patchBody }),
    handle(async (req) => ok(await service.update(req.params.branchId, req.body, authOf(req).userId))),
  );
  r.post(
    '/admin/branches/:branchId/status',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: idParam, body: statusBody }),
    handle(async (req) =>
      ok(
        await service.setStatus(req.params.branchId, req.body.isActive, req.body.reason, authOf(req).userId),
      ),
    ),
  );
  r.post(
    '/admin/branches/:branchId/qr/rotate',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: idParam, body: rotateBody }),
    handle(async (req) =>
      ok(await service.rotateQr(req.params.branchId, req.body.reason, authOf(req).userId)),
    ),
  );
  return r;
}
