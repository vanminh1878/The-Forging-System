import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { MembershipService } from './membership.service';

const packageQuery = z.object({ includeInactive: z.enum(['true', 'false']).optional() });

export function membershipRoutes(service: MembershipService): Router {
  const r = Router();
  r.use(requireAuth);

  // Any signed-in user: the renewal modal shows the price. Only admins may see inactive types.
  r.get(
    '/package-types',
    validate({ query: packageQuery }),
    handle(async (req) => {
      const isAdmin = authOf(req).roles.some((role) =>
        (RoleGroup.ADMINS as readonly string[]).includes(role),
      );
      return ok(await service.listPackageTypes(isAdmin && req.query.includeInactive === 'true'));
    }),
  );
  return r;
}
