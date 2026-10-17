import { z } from 'zod';

const email = z.string().trim().toLowerCase().email().max(254);
const otp = z.string().trim().length(6);

export const registerOtpBody = z.object({ email });

export const registerBody = z.object({
  fullName: z.string().trim().min(2).max(100),
  email,
  phone: z.string().trim().min(9).max(16),
  password: z.string().min(6).max(72),
  passwordConfirm: z.string().optional(),
  homeBranchId: z.string().uuid().optional(),
  otpRequestId: z.string().uuid(),
  otp,
});

export const loginBody = z.object({
  identifier: z.string().trim().min(3),
  password: z.string().min(1),
});

export const refreshBody = z.object({ refreshToken: z.string().min(10) });
export const logoutBody = z.object({ refreshToken: z.string().optional() });

export const forgotBody = z.object({ email });
export const verifyPinBody = z.object({ requestId: z.string().uuid(), pin: otp });
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
