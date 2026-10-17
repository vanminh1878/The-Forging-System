import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

export type OtpPurpose = 'REGISTER' | 'PASSWORD_RESET';

/** Strategy for delivering one-time PINs by e-mail. */
export interface OtpSender {
  send(email: string, pin: string, purpose: OtpPurpose, ttlMinutes: number): Promise<void>;
}

/** Development sender: writes the PIN to the log instead of sending it. */
export class ConsoleOtpSender implements OtpSender {
  async send(email: string, pin: string, purpose: OtpPurpose): Promise<void> {
    logger.info({ email, purpose }, `[otp:console] PIN ${pin}`);
  }
}

/** Alias of the published Resend template built from `otp-email.html` (see scripts/resend-template.ts). */
export const OTP_TEMPLATE_ALIAS = 'hvp-otp';

const COPY: Record<OtpPurpose, { subject: string; heading: string; intro: string }> = {
  REGISTER: {
    subject: 'Mã xác thực đăng ký HVP',
    heading: 'Xác thực email đăng ký',
    intro: 'Chào mừng bạn đến với HVP Boxing. Nhập mã dưới đây trong ứng dụng để hoàn tất đăng ký tài khoản.',
  },
  PASSWORD_RESET: {
    subject: 'Mã đặt lại mật khẩu HVP',
    heading: 'Đặt lại mật khẩu',
    intro: 'Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản HVP của bạn. Nhập mã dưới đây trong ứng dụng để tiếp tục.',
  },
};

/** Sends the PIN through the Resend HTTP API using the published `hvp-otp` template. */
export class ResendOtpSender implements OtpSender {
  constructor(
    private readonly apiKey: string,
    private readonly from: string,
    private readonly bcc?: string,
  ) {}

  async send(email: string, pin: string, purpose: OtpPurpose, ttlMinutes: number): Promise<void> {
    const copy = COPY[purpose];
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: this.from,
        to: [email],
        ...(this.bcc ? { bcc: [this.bcc] } : {}),
        subject: copy.subject,
        template: {
          id: OTP_TEMPLATE_ALIAS,
          variables: { HEADING: copy.heading, INTRO: copy.intro, PIN: pin, TTL_MINUTES: ttlMinutes },
        },
      }),
    });
    // Runs after commit: a failure is logged and the user can request a new code.
    if (!res.ok) logger.error({ email, purpose, status: res.status, body: await res.text() }, 'resend: OTP mail failed');
  }
}

export function createOtpSender(): OtpSender {
  if (env.OTP_PROVIDER === 'resend') return new ResendOtpSender(env.RESEND_API_KEY!, env.MAIL_FROM!, env.MAIL_BCC);
  return new ConsoleOtpSender();
}
