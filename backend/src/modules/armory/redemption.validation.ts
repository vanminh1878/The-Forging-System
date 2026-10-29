import { z } from 'zod';

const uuid = z.string().uuid().transform((value) => value.toLowerCase());
export const createRedemptionBody = z.object({
  rewardId: uuid,
  pickupBranchId: uuid,
  idempotencyKey: uuid.optional(),
}).strict();

export const redemptionIdParam = z.object({ redemptionId: uuid });
export const cancelRedemptionBody = z.object({ reason: z.string().trim().min(3).max(500).optional() }).strict();
export const redemptionDecisionBody = z.discriminatedUnion('status', [
  z.object({ status: z.literal('DELIVERED'), reason: z.string().trim().min(3).max(500).optional(), deliveryEvidenceUrl: z.string().url().max(2000).optional() }).strict(),
  z.object({ status: z.literal('REJECTED'), reason: z.string().trim().min(3).max(500), deliveryEvidenceUrl: z.string().url().max(2000).optional() }).strict(),
]);

export type CreateRedemptionInput = z.infer<typeof createRedemptionBody>;
