import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { PointsService } from './points.service';

const ledgerQuery = paginationQuery.extend({
  source: z
    .enum([
      'OPENING',
      'SESSION',
      'ATTITUDE',
      'ACADEMY',
      'STREAK_MILESTONE',
      'CHALLENGE',
      'RANK_TRIAL',
      'EARLY_RENEWAL',
      'COMEBACK',
      'ARMORY_REDEEM',
      'MANUAL_ADJUSTMENT',
      'REVERSAL',
    ])
    .optional(),
});
const memberParam = z.object({ memberId: z.string().uuid() });
const txParam = z.object({ transactionId: z.string().uuid() });
const adjustBody = z.object({
  dpDelta: z.number().int(),
  marksDelta: z.number().int().optional(),
  reason: z.string().trim().min(3).max(500),
  confirmed: z.boolean().optional(),
});
const reverseBody = z.object({ reason: z.string().trim().min(3).max(500) });

export function pointsRoutes(service: PointsService): Router {
  const r = Router();
  r.use(requireAuth);

  // Learner: own ledger (must match the admin view of the same member).
  r.get(
    '/me/points/transactions',
    requireRoles(Role.MEMBER),
    validate({ query: ledgerQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof ledgerQuery>;
      const page = toPage(q);
      const { items, total } = await service.listForMember(
        authOf(req).userId,
        { source: q.source },
        page.limit,
        page.offset,
      );
      return ok(items, pageMeta(page, total));
    }),
  );
  r.get(
    '/me/points/monthly',
    requireRoles(Role.MEMBER),
    handle(async (req) => ok(await service.monthlyStatus(authOf(req).userId))),
  );
  // ARM-04: available Marks are the balance less the sum of PENDING_PICKUP holds.
  r.get(
    '/me/armory/wallet',
    requireRoles(Role.MEMBER),
    handle(async (req) => ok(await service.wallet(authOf(req).userId))),
  );

  // Staff: any member's ledger.
  r.get(
    '/members/:memberId/points/transactions',
    requireRoles(...RoleGroup.STAFF),
    validate({ params: memberParam, query: ledgerQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof ledgerQuery>;
      const page = toPage(q);
      const { items, total } = await service.listForMember(
        req.params.memberId,
        { source: q.source },
        page.limit,
        page.offset,
      );
      return ok(items, pageMeta(page, total));
    }),
  );

  // Admin corrections (ADM-08).
  r.post(
    '/admin/members/:memberId/points/adjust',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: memberParam, body: adjustBody }),
    handle(async (req) =>
      created(
        await service.manualAdjust({ memberId: req.params.memberId, ...req.body, by: authOf(req).userId }),
      ),
    ),
  );
  r.post(
    '/admin/points/transactions/:transactionId/reverse',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: txParam, body: reverseBody }),
    handle(async (req) =>
      created(
        await service.reverse({
          transactionId: req.params.transactionId,
          reason: req.body.reason,
          by: authOf(req).userId,
        }),
      ),
    ),
  );
  return r;
}
