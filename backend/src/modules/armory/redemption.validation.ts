import { z } from 'zod';
import { paginationQuery } from '../../common/http/pagination';

const uuid = z.string().uuid().transform((value) => value.toLowerCase());
export const createRedemptionBody = z.object({
  rewardId: uuid,
  pickupBranchId: uuid,
  idempotencyKey: uuid.optional(),
}).strict();

export type CreateRedemptionInput = z.infer<typeof createRedemptionBody>;
export const redemptionIdParam = z.object({ redemptionId: uuid });
export const redemptionHistoryQuery = paginationQuery.extend({
  status: z.enum(['PENDING_PICKUP', 'DELIVERED', 'REJECTED', 'CANCELLED', 'EXPIRED']).optional(),
}).strict();
