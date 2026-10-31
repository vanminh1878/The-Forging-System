import { z } from 'zod';
import { paginationQuery } from '../../common/http/pagination';

const uuid = z
  .string()
  .uuid()
  .transform((value) => value.toLowerCase());
export const createRedemptionBody = z
  .object({
    rewardId: uuid,
    pickupBranchId: uuid,
    idempotencyKey: uuid.optional(),
  })
  .strict();

export type CreateRedemptionInput = z.infer<typeof createRedemptionBody>;

export const redemptionIdParam = z.object({ redemptionId: uuid });
export const redemptionHistoryQuery = paginationQuery
  .extend({
    status: z.enum(['PENDING_PICKUP', 'DELIVERED', 'REJECTED', 'CANCELLED', 'EXPIRED']).optional(),
  })
  .strict();
export type RedemptionHistoryFilter = Pick<z.infer<typeof redemptionHistoryQuery>, 'status'>;
export const cancelBody = z.object({ reason: z.string().trim().min(3).max(500).optional() }).strict();
export const decisionBody = z.discriminatedUnion('status', [
  z
    .object({
      status: z.literal('DELIVERED'),
      reason: z.string().trim().min(3).max(500).optional(),
      deliveryEvidenceUrl: z
        .string()
        .url()
        .max(2000)
        .refine((value) => /^https?:\/\//i.test(value))
        .optional(),
    })
    .strict(),
  z.object({ status: z.literal('REJECTED'), reason: z.string().trim().min(3).max(500) }).strict(),
]);
export type RedemptionDecision = z.infer<typeof decisionBody>;
