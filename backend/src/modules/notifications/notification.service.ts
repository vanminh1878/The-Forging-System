import { db } from '../../db/database';
import { logger } from '../../common/utils/logger';
import { badRequest, notFound } from '../../common/errors/app-error';
import { Role } from '../../shared/roles';
import type { AuditService } from '../audit/audit.service';
import type { NotificationRepository } from './notification.repository';
import { fillTemplate, TEMPLATE_BY_EVENT } from './notification.events';
import type { PushProvider } from './push.provider';

export interface NotifyInput {
  userId: string;
  event: string;
  title: string;
  body: string;
  payload?: unknown;
  /** Same key => the notification is created at most once (batch jobs run repeatedly). */
  dedupeKey?: string;
}

/** Port used by every other module to create notifications. */
export interface NotifierPort {
  notifyMember(input: NotifyInput): Promise<boolean>;
  notifyFromTemplate(
    userId: string,
    event: string,
    vars: Record<string, string | number>,
    opts?: { dedupeKey?: string; payload?: unknown },
  ): Promise<boolean>;
  notifyStaff(toRole: 'ADMIN' | 'COACH' | 'RECEPTIONIST', event: string, title: string, body: string): Promise<void>;
}

export class NotificationService implements NotifierPort {
  constructor(
    private readonly repo: NotificationRepository,
    private readonly push: PushProvider,
    private readonly audit: AuditService,
  ) {}

  /** Creates a personal notification and, after the transaction commits, pushes it to the user's devices. */
  async notifyMember(input: NotifyInput): Promise<boolean> {
    const id = await this.repo.insertPersonal(input);
    if (!id) return false; // deduplicated
    const tokens = await this.repo.tokensForUser(input.userId);
    if (tokens.length === 0) return true;
    db.afterCommit(() => this.deliverPush(tokens.map((t) => t.token), input, id));
    return true;
  }

  /**
   * Renders the tenant's template (falling back to the built-in copy) and sends it.
   * A disabled template silently skips the notification.
   */
  async notifyFromTemplate(
    userId: string,
    event: string,
    vars: Record<string, string | number>,
    opts: { dedupeKey?: string; payload?: unknown } = {},
  ): Promise<boolean> {
    const fallback = TEMPLATE_BY_EVENT.get(event);
    const custom = await this.repo.findTemplate(event);
    if (custom && !custom.isEnabled) return false;
    const title = custom?.title ?? fallback?.title ?? event;
    const body = custom?.body ?? fallback?.body ?? '';
    return this.notifyMember({
      userId,
      event,
      title: fillTemplate(title, vars),
      body: fillTemplate(body, vars),
      dedupeKey: opts.dedupeKey,
      payload: opts.payload,
    });
  }

  async notifyStaff(toRole: 'ADMIN' | 'COACH' | 'RECEPTIONIST', event: string, title: string, body: string): Promise<void> {
    await this.repo.insertStaff(toRole, event, title, body);
  }

  // ---------- reads ----------

  async listForMember(userId: string, limit: number, offset: number) {
    const [items, unread] = await Promise.all([
      this.repo.listForMember(userId, limit, offset),
      this.repo.countUnreadForMember(userId),
    ]);
    return { items, unread };
  }

  unreadCountForMember(userId: string): Promise<number> {
    return this.repo.countUnreadForMember(userId);
  }

  markAllReadForMember(userId: string): Promise<void> {
    return this.repo.markAllReadForMember(userId);
  }

  markOneReadForMember(userId: string, id: string): Promise<void> {
    return this.repo.markOneReadForMember(userId, id);
  }

  /** Staff roles whose inbox a user can read: Head Coach also reads Coach, Super Admin also reads Admin. */
  private inboxRoles(roles: readonly string[]): string[] {
    const out = new Set<string>();
    for (const r of roles) {
      if (r === Role.ADMIN || r === Role.SUPER_ADMIN) out.add('ADMIN');
      if (r === Role.COACH || r === Role.HEAD_COACH) out.add('COACH');
      if (r === Role.RECEPTIONIST) out.add('RECEPTIONIST');
    }
    return [...out];
  }

  async listForStaff(roles: readonly string[], limit: number) {
    const inbox = this.inboxRoles(roles);
    const [items, unread] = await Promise.all([this.repo.listStaff(inbox, limit), this.repo.countUnreadStaff(inbox)]);
    return { items, unread };
  }

  async markStaffRead(roles: readonly string[]): Promise<void> {
    await this.repo.markStaffRead(this.inboxRoles(roles));
  }

  // ---------- admin: broadcast & templates ----------

  async sendBroadcast(input: {
    scope: 'all' | 'branch' | 'rank';
    branchId?: string;
    rankId?: string;
    title: string;
    body: string;
    sentBy: string;
  }): Promise<{ id: string; audienceCount: number }> {
    const branchId = input.scope === 'branch' ? (input.branchId ?? null) : null;
    const rankId = input.scope === 'rank' ? (input.rankId ?? null) : null;
    if (input.scope === 'branch' && !branchId) throw badRequest('branchId is required for a branch broadcast');
    if (input.scope === 'rank' && !rankId) throw badRequest('rankId is required for a rank broadcast');

    const id = await this.repo.insertBroadcast({ title: input.title, body: input.body, branchId, rankId, sentBy: input.sentBy });
    const audienceCount = await this.repo.countBroadcastAudience(branchId, rankId);
    await this.audit.record({
      actorId: input.sentBy,
      action: 'NOTIFICATION_BROADCAST',
      entityType: 'NOTIFICATION',
      entityId: id,
      after: { scope: input.scope, audienceCount },
      reason: input.title,
    });
    const tokens = await this.repo.tokensForBroadcast(branchId, rankId);
    if (tokens.length > 0) {
      db.afterCommit(() => this.deliverPush(tokens.map((t) => t.token), { event: 'BROADCAST', title: input.title, body: input.body }, id));
    }
    return { id, audienceCount };
  }

  listTemplates() {
    return this.repo.listTemplates();
  }

  async upsertTemplate(input: { event: string; title: string; body: string; isEnabled: boolean; updatedBy: string }) {
    if (!TEMPLATE_BY_EVENT.has(input.event)) throw notFound('Notification template');
    await this.repo.upsertTemplate(input);
  }

  // ---------- internals ----------

  /** Runs after commit, outside the request transaction: failures never roll back business data. */
  private async deliverPush(tokens: string[], msg: { event: string; title: string; body: string }, notificationId: string): Promise<void> {
    try {
      const result = await this.push.send(tokens, { title: msg.title, body: msg.body, data: { event: msg.event, notificationId } });
      if (result.invalidTokens.length > 0) {
        logger.info({ count: result.invalidTokens.length }, 'push: invalid device tokens detected');
      }
    } catch (err) {
      logger.error({ err, notificationId }, 'push delivery failed');
    }
  }
}
