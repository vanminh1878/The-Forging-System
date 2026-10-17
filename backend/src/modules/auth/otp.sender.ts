import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

export type OtpPurpose = 'REGISTER' | 'PASSWORD_RESET';

/** Strategy for delivering one-time PINs by e-mail. */
export interface OtpSender {
  send(email: string, pin: string, purpose: OtpPurpose): Promise<void>;
}

/** Development sender: writes the PIN to the log instead of sending it. */
export class ConsoleOtpSender implements OtpSender {
  async send(email: string, pin: string, purpose: OtpPurpose): Promise<void> {
    logger.info({ email, purpose }, `[otp:console] PIN ${pin}`);
  }
}

const SUBJECT: Record<OtpPurpose, string> = {
  REGISTER: 'Mã xác thực đăng ký HVP',
  PASSWORD_RESET: 'Mã đặt lại mật khẩu HVP',
};

/** Sends the PIN through the Resend HTTP API (https://resend.com/docs/api-reference/emails/send-email). */
export class ResendOtpSender implements OtpSender {
  constructor(
    private readonly apiKey: string,
    private readonly from: string,
    private readonly bcc?: string,
  ) {}

  async send(email: string, pin: string, purpose: OtpPurpose): Promise<void> {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: this.from,
        to: [email],
        ...(this.bcc ? { bcc: [this.bcc] } : {}),
        subject: SUBJECT[purpose],
        text: `Mã xác thực của bạn là ${pin}. Mã có hiệu lực trong vài phút, vui lòng không chia sẻ cho bất kỳ ai.`,
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
