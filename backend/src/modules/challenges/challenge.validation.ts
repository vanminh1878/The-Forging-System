import { z } from 'zod';
import { paginationQuery } from '../../common/http/pagination';

export const challengeType = z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'EVENT']);
export const challengeContext = z.enum(['SESSION', 'WORKSHOP', 'EXAM']);
export const challengeStatus = z.enum(['DRAFT', 'OPEN', 'CLOSED', 'CANCELLED']);
const nonnegativeInt = z.number().int().min(0).max(2_147_483_647);
const fields = {
  code: z
    .string()
    .trim()
    .toUpperCase()
    .min(2)
    .max(64)
    .regex(/^[A-Z0-9_-]+$/)
    .nullable(),
  title: z.string().trim().min(2).max(150),
  description: z.string().trim().max(2000).nullable(),
  challengeType,
  context: challengeContext,
  target: z.number().int().min(1).max(2_147_483_647),
  rewardDp: nonnegativeInt,
  rewardMarks: nonnegativeInt,
  startsAt: z.string().datetime({ offset: true }),
  endsAt: z.string().datetime({ offset: true }),
};

export const createChallengeBody = z
  .object({
    ...fields,
    code: fields.code.optional().default(null),
    description: fields.description.optional().default(null),
    context: fields.context.default('SESSION'),
    target: fields.target.default(1),
    rewardDp: fields.rewardDp.default(0),
    rewardMarks: fields.rewardMarks.default(0),
  })
  .strict();

export const updateChallengeBody = z
  .object(fields)
  .partial()
  .extend({
    reason: z.string().trim().min(3).max(500),
  })
  .strict()
  .refine((body) => Object.keys(body).some((key) => key !== 'reason'), {
    message: 'Cần ít nhất một trường thử thách để cập nhật.',
  });

export const challengeIdParam = z.object({ challengeId: z.string().uuid() });
export const participationIdParam = z.object({ participationId: z.string().uuid() });
export const challengeEvidenceBody = z
  .object({
    evidenceUrl: z.string().trim().url().max(1000),
  })
  .strict();
export const staffParticipationQuery = paginationQuery
  .extend({
    status: z.enum(['PENDING_COACH', 'JOINED', 'AWAITING_COACH', 'REWARDED', 'EXPIRED']).optional(),
    evidence: z.enum(['SUBMITTED', 'PENDING']).optional(),
    q: z.string().trim().min(1).max(100).optional(),
  })
  .strict();
export const challengeEnabledBody = z
  .object({
    enabled: z.boolean(),
    reason: z.string().trim().min(3).max(500),
  })
  .strict();
export const challengeSearchQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  status: challengeStatus.optional(),
  challengeType: challengeType.optional(),
  context: challengeContext.optional(),
});

export const openChallengeQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  challengeType: challengeType.optional(),
  period: challengeType.optional(),
  context: challengeContext.optional(),
});

export type CreateChallengeInput = z.infer<typeof createChallengeBody>;
export type UpdateChallengeInput = z.infer<typeof updateChallengeBody>;
export type ChallengeEnabledInput = z.infer<typeof challengeEnabledBody>;
export type ChallengeEvidenceInput = z.infer<typeof challengeEvidenceBody>;
export type StaffParticipationFilter = Pick<
  z.infer<typeof staffParticipationQuery>,
  'status' | 'evidence' | 'q'
>;
export type ChallengeFilter = Pick<
  z.infer<typeof challengeSearchQuery>,
  'q' | 'status' | 'challengeType' | 'context'
>;
export type OpenChallengeFilter = Pick<
  z.infer<typeof openChallengeQuery>,
  'q' | 'challengeType' | 'period' | 'context'
>;
