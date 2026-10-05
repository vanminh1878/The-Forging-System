import { createRequire } from 'node:module';
import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  /** Tokens the provider reported as permanently invalid (to be disabled). */
  invalidTokens: string[];
}

/** Strategy interface for push delivery (console in dev, FCM in production). */
export interface PushProvider {
  send(tokens: string[], message: PushMessage): Promise<PushResult>;
}

export class ConsolePushProvider implements PushProvider {
  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    logger.info({ tokens: tokens.length, title: message.title }, `[push:console] ${message.title} - ${message.body}`);
    return { invalidTokens: [] };
  }
}

/**
 * Firebase Cloud Messaging via firebase-admin. The package is an optional
 * dependency: install it and set GOOGLE_APPLICATION_CREDENTIALS to enable.
 */
export class FcmPushProvider implements PushProvider {
  private messaging: {
    sendEachForMulticast: (m: unknown) => Promise<{ responses: { success: boolean; error?: { code?: string } }[] }>;
  } | null = null;

  private init() {
    if (this.messaging) return this.messaging;
    const req = createRequire(__filename);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const admin = req('firebase-admin') as any;
    if (!admin.apps.length) admin.initializeApp();
    this.messaging = admin.messaging();
    return this.messaging!;
  }

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    if (tokens.length === 0) return { invalidTokens: [] };
    const res = await this.init().sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data ?? {},
    });
    const invalidTokens = res.responses
      .map((r, i) => (!r.success && r.error?.code === 'messaging/registration-token-not-registered' ? tokens[i] : null))
      .filter((t): t is string => t !== null);
    return { invalidTokens };
  }
}

export function createPushProvider(): PushProvider {
  return env.PUSH_PROVIDER === 'fcm' ? new FcmPushProvider() : new ConsolePushProvider();
}
