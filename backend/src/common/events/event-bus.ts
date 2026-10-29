import { logger } from '../utils/logger';

/**
 * In-process domain event bus.
 *
 * Handlers are awaited sequentially and run inside the emitter's database
 * transaction (AsyncLocalStorage context is inherited), so a business action
 * and all of its reactions commit or roll back together. A failing handler
 * therefore aborts the whole action - handlers must only do work that is
 * required for consistency. Fire-and-forget side effects belong in
 * db.afterCommit().
 */
export type EventHandler<P> = (payload: P) => Promise<void> | void;

export class EventBus {
  private handlers = new Map<string, EventHandler<never>[]>();

  on<P>(event: string, handler: EventHandler<P>): void {
    const list = this.handlers.get(event) ?? [];
    list.push(handler as EventHandler<never>);
    this.handlers.set(event, list);
  }

  async emit<P>(event: string, payload: P): Promise<void> {
    const list = this.handlers.get(event) ?? [];
    for (const handler of list) {
      logger.debug({ event }, 'domain event');
      await (handler as EventHandler<P>)(payload);
    }
  }

  /** Test helper. */
  clear(): void {
    this.handlers.clear();
  }
}

export const eventBus = new EventBus();

/** Central registry of event names to avoid string typos across modules. */
export const DomainEvents = {
  ATTENDANCE_CONFIRMED: 'attendance.confirmed',
  ACADEMY_RESULT_RECORDED: 'attendance.academy_result_recorded',
  POINTS_AWARDED: 'points.awarded',
  RANK_CHANGED: 'rank.changed',
  MEMBERSHIP_ACTIVATED: 'membership.activated',
  MEMBERSHIP_SCHEDULED: 'membership.scheduled',
  MEMBERSHIP_EXPIRED: 'membership.expired',
  MEMBERSHIP_CANCELLED: 'membership.cancelled',
  MEMBERSHIP_COMPLETED: 'membership.completed',
  COURSE_COMPLETED: 'course.completed',
  STREAK_WEEK_CLOSED: 'streak.week_closed',
  MEMBER_STATUS_CHANGED: 'member.status_changed',
  REDEMPTION_CREATED: 'redemption.created',
  SESSION_CANCELLED: 'session.cancelled',
  SESSION_RESCHEDULED: 'session.rescheduled',
} as const;
