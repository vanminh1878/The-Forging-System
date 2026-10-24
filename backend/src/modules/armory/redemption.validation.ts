import { z } from 'zod';

const uuid = z.string().uuid().transform((value) => value.toLowerCase());
export const createRedemptionBody = z.object({
  rewardId: uuid,
  pickupBranchId: uuid,
  idempotencyKey: uuid.optional(),
}).strict();

export type CreateRedemptionInput = z.infer<typeof createRedemptionBody>;
