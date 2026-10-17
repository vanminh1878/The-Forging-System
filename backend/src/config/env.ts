import 'dotenv/config';
import { z } from 'zod';

/**
 * Typed, validated environment. The process fails fast at startup when a
 * required variable is missing or malformed.
 */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

  DEFAULT_TENANT_CODE: z.string().min(1).default('hvp'),
  APP_TIMEZONE: z.string().min(1).default('Asia/Ho_Chi_Minh'),

  DATABASE_URL: z.string().url(),
  DATABASE_MIGRATE_URL: z.string().url().optional(),

  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_ACCESS_TTL: z.string().default('15m'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  BCRYPT_ROUNDS: z.coerce.number().int().min(4).max(14).default(10),

  UPLOAD_DIR: z.string().default('./uploads'),
  PUBLIC_BASE_URL: z.string().url().default('http://localhost:4000'),

  ENABLE_SCHEDULER: z
    .enum(['true', 'false'])
    .default('true')
    .transform((v) => v === 'true'),

  PUSH_PROVIDER: z.enum(['console', 'fcm']).default('console'),
  OTP_PROVIDER: z.enum(['console', 'resend']).default('console'),
  RESEND_API_KEY: z.string().min(1).optional(),
  /** Sender, e.g. `HVP <no-reply@hvp.vn>` (the domain must be verified in Resend). */
  MAIL_FROM: z.string().min(3).optional(),
  /** Optional address that receives a blind copy of every OTP mail. */
  MAIL_BCC: z.string().trim().email().optional().or(z.literal('').transform(() => undefined)),
}).superRefine((v, ctx) => {
  if (v.OTP_PROVIDER !== 'resend') return;
  for (const key of ['RESEND_API_KEY', 'MAIL_FROM'] as const) {
    if (!v[key]) ctx.addIssue({ code: z.ZodIssueCode.custom, path: [key], message: 'required when OTP_PROVIDER=resend' });
  }
});

export type Env = z.infer<typeof schema>;

function load(): Env {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    const details = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration -> ${details}`);
  }
  return parsed.data;
}

export const env: Env = load();
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';
