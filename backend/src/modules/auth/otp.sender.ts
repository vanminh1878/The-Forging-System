import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

/** Strategy for delivering one-time PINs (SMS or e-mail). */
export interface OtpSender {
  send(channel: 'SMS' | 'EMAIL', destination: string, pin: string): Promise<void>;
}

/** Development sender: writes the PIN to the log instead of sending it. */
export class ConsoleOtpSender implements OtpSender {
  async send(channel: 'SMS' | 'EMAIL', destination: string, pin: string): Promise<void> {
    logger.info({ channel, destination }, `[otp:console] PIN ${pin}`);
  }
}

export function createOtpSender(): OtpSender {
  if (env.OTP_PROVIDER === 'smtp') {
    throw new Error('OTP_PROVIDER=smtp is not implemented yet: add an SmtpOtpSender and register it here.');
  }
  return new ConsoleOtpSender();
}
