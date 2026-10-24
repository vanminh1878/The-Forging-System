import { z } from 'zod';
import { paginationQuery } from '../../common/http/pagination';

const int = z.number().int().min(0).max(2_147_483_647);
const reason = z.string().trim().min(3).max(500);
const tierCode = z.string().trim().toUpperCase().min(2).max(50).regex(/^[A-Z0-9_]+$/);
const tierFields = {
  name: z.string().trim().min(2).max(100),
  minMarks: int,
  maxMarks: int.nullable(),
  sortOrder: z.number().int().min(0).max(32767),
};
export const createTierBody = z.object({ code: tierCode, ...tierFields,
  maxMarks: tierFields.maxMarks.default(null), sortOrder: tierFields.sortOrder.default(0),
}).strict();
export const updateTierBody = z.object(tierFields).partial().extend({ reason }).strict()
  .refine((body) => Object.keys(body).some((key) => key !== 'reason'), { message: 'Cần trường tầng quà để cập nhật.' });
export const tierParam = z.object({ tierCode });

const rewardFields = {
  name: z.string().trim().min(2).max(150),
  description: z.string().trim().max(2000).nullable(),
  imageUrl: z.string().url().max(2000).refine((value) => /^https?:\/\//i.test(value), 'Image URL phải là HTTP(S).').nullable(),
  tierCode: tierCode.nullable(),
  marksCost: int.refine((value) => value > 0, 'Marks cost phải lớn hơn 0.'),
  stock: int,
  perMemberLimit: int.refine((value) => value > 0).nullable(),
  limitPeriod: z.enum(['MONTH', 'YEAR', 'LIFETIME']).nullable(),
  minRankId: z.string().uuid().nullable(),
  pickupDays: z.number().int().min(1).max(32767).nullable(),
  saleStartsAt: z.string().datetime({ offset: true }).nullable(),
  saleEndsAt: z.string().datetime({ offset: true }).nullable(),
  isActive: z.boolean(),
};
export const createRewardBody = z.object({
  sku: z.string().trim().toUpperCase().min(2).max(80).regex(/^[A-Z0-9][A-Z0-9._-]*$/),
  ...rewardFields,
  description: rewardFields.description.default(null), imageUrl: rewardFields.imageUrl.default(null),
  tierCode: rewardFields.tierCode.default(null), stock: rewardFields.stock.default(0),
  perMemberLimit: rewardFields.perMemberLimit.default(null), limitPeriod: rewardFields.limitPeriod.default(null),
  minRankId: rewardFields.minRankId.default(null), pickupDays: rewardFields.pickupDays.default(null),
  saleStartsAt: rewardFields.saleStartsAt.default(null), saleEndsAt: rewardFields.saleEndsAt.default(null),
  isActive: rewardFields.isActive.default(true),
}).strict();
export const updateRewardBody = z.object(rewardFields).partial().extend({ reason }).strict()
  .refine((body) => Object.keys(body).some((key) => key !== 'reason'), { message: 'Cần trường phần quà để cập nhật.' });
export const rewardParam = z.object({ rewardId: z.string().uuid() });
export const adminRewardQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(), tierCode: tierCode.optional(),
  isActive: z.enum(['true', 'false']).transform((value) => value === 'true').optional(),
}).strict();

export type CreateTierInput = z.infer<typeof createTierBody>;
export type UpdateTierInput = z.infer<typeof updateTierBody>;
export type CreateRewardInput = z.infer<typeof createRewardBody>;
export type UpdateRewardInput = z.infer<typeof updateRewardBody>;
export type AdminRewardFilter = Pick<z.infer<typeof adminRewardQuery>, 'q' | 'tierCode' | 'isActive'>;
