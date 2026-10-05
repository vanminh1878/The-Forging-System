import { z } from 'zod';

export const registerBody = z.object({
  fullName: z.string().trim().min(2).max(100),
  email: z.string().trim().email().optional().or(z.literal('').transform(() => undefined)),
  phone: z.string().trim().min(9).max(16),
  password: z.string().min(6).max(72),
  passwordConfirm: z.string().optional(),
  homeBranchId: z.string().uuid().optional(),
});

export const loginBody = z.object({
  identifier: z.string().trim().min(3),
  password: z.string().min(1),
});

export const refreshBody = z.object({ refreshToken: z.string().min(10) });
export const logoutBody = z.object({ refreshToken: z.string().optional() });

export const forgotBody = z.object({ phone: z.string().trim().min(9).max(16) });
export const verifyPinBody = z.object({ requestId: z.string().uuid(), pin: z.string().trim().length(6) });
export const resetBody = z.object({
  requestId: z.string().uuid(),
  resetToken: z.string().min(10),
  password: z.string().min(6).max(72),
  passwordConfirm: z.string(),
});

export const deviceBody = z.object({
  token: z.string().min(10).max(4096),
  platform: z.enum(['ANDROID', 'IOS', 'WEB']),
  provider: z.enum(['FCM', 'APNS']).optional(),
});
export const deviceDeleteBody = z.object({ token: z.string().min(10) });
