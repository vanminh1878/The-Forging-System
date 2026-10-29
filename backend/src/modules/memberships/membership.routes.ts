import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { MembershipService } from './membership.service';

const memberParam = z.object({ memberId: z.string().uuid() });
const requestBody = z.object({
  packageTypeId: z.string().uuid(),
  note: z.string().trim().max(500).optional(),
});
const activateBody = z.object({
  packageTypeId: z.string().uuid(),
  paymentEvidenceUrl: z.string().trim().max(1000).optional(),
  branchId: z.string().uuid().optional(),
  note: z.string().trim().max(500).optional(),
});
const approveBody = z.object({
  paymentEvidenceUrl: z.string().trim().max(1000).optional(),
  packageTypeId: z.string().uuid().optional(),
  note: z.string().trim().max(500).optional(),
});
const idParam = z.object({ id: z.string().uuid() });
const inboxQuery = paginationQuery.extend({
  status: z.enum(['PENDING', 'COMPLETED', 'CANCELLED']).optional(),
  q: z.string().trim().max(100).optional(),
});
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

  // Learner home card (HV-03) and the reception view of the same member.
  r.get(
    '/me/membership',
    requireRoles(Role.MEMBER),
    handle(async (req) => ok(await service.getMembershipOverview(authOf(req).userId))),
  );
  r.get(
    '/members/:memberId/membership',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: memberParam }),
    handle(async (req) => ok(await service.getMembershipOverview(req.params.memberId, true))),
  );
  r.post(
    '/members/:memberId/memberships',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: memberParam, body: activateBody }),
    handle(async (req) => {
      const a = authOf(req);
      return created(await service.activateManually(req.params.memberId, a.userId, a.roles, req.body));
    }),
  );
  r.post(
    '/renewal-requests/:id/approve',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: idParam, body: approveBody }),
    handle(async (req) => {
      const a = authOf(req);
      return ok(await service.approveRenewal(req.params.id, a.userId, a.roles, req.body));
    }),
  );

  // Renewal requests: learner sends and reads history; front desk reads the inbox (approve: MEM-04, cancel: MEM-06).
  r.post(
    '/me/renewal-requests',
    requireRoles(Role.MEMBER),
    validate({ body: requestBody }),
    handle(async (req) => created(await service.requestRenewal(authOf(req).userId, req.body))),
  );
  r.get(
    '/me/renewal-requests',
    requireRoles(Role.MEMBER),
    validate({ query: paginationQuery }),
    handle(async (req) => {
      const page = toPage(req.query as unknown as z.infer<typeof paginationQuery>);
      const { items, total } = await service.listRenewals(
        { memberId: authOf(req).userId },
        page.limit,
        page.offset,
      );
      return ok(items, pageMeta(page, total));
    }),
  );
  r.get(
    '/renewal-requests',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ query: inboxQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof inboxQuery>;
      const page = toPage(q);
      const { items, total } = await service.listRenewals(
        { status: q.status, q: q.q },
        page.limit,
        page.offset,
      );
      return ok(items, pageMeta(page, total));
    }),
  );
  return r;
}
