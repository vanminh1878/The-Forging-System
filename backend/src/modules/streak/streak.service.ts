import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import {
  addDays,
  addMonthsToDate,
  localDate,
  monthStartOf,
  startOfLocalDay,
  weekStartOf,
} from '../../common/utils/time';
import type { AuditService } from '../audit/audit.service';
import type { PointsPort } from '../points/points.service';
import type { SettingsService } from '../settings/settings.service';
import type { NotifierPort } from '../notifications/notification.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { StreakRepository, StreakResult } from './streak.repository';
import { notFound } from '../../common/errors/app-error';

export class StreakService {
  constructor(
    private readonly repo: StreakRepository,
    private readonly settings: SettingsService,
    private readonly points: PointsPort,
    private readonly audit: AuditService,
    private readonly notifications: NotifierPort,
  ) {}

  async closePreviousWeek(now = clock.now()): Promise<string[]> {
    const thisWeek = weekStartOf(localDate(now));
    const weekStart = addDays(thisWeek, -7);
    const start = startOfLocalDay(weekStart);
    const end = startOfLocalDay(thisWeek);
    const memberIds = await this.repo.activeMemberIdsForWeek(start, end);
    const lines: string[] = [];
    for (const memberId of memberIds) {
      const result = await this.closeMember(memberId, weekStart, start, end, now);
      lines.push(`${memberId}: ${result}`);
    }
    return lines;
  }

  async summary(memberId: string, now = clock.now()) {
    const member = await this.repo.member(memberId);
    if (!member) throw notFound('Member');
    const currentWeekStart = weekStartOf(localDate(now));
    const targetSessions = await this.settings.getNumber('streak.weekly_min_sessions');
    const sessionsThisWeek = await this.repo.countConfirmedSessions(
      memberId,
      startOfLocalDay(currentWeekStart),
      startOfLocalDay(addDays(currentWeekStart, 7)),
    );
    const milestones = await this.settings.get<Record<string, unknown>>('streak.milestones');
    return {
      ...member,
      currentWeekStart,
      sessionsThisWeek,
      targetSessions,
      milestones: Object.entries(milestones)
        .map(([week, dp]) => ({ week: Number(week), dp: Number(dp) }))
        .filter(({ week, dp }) => Number.isInteger(week) && week > 0 && Number.isInteger(dp) && dp > 0)
        .sort((a, b) => a.week - b.week),
      availableFreezes: await this.repo.availableFreezes(memberId, now),
      logs: await this.repo.recentLogs(memberId),
    };
  }

  async warnAtRiskMembers(now = clock.now()): Promise<string[]> {
    const weekStart = weekStartOf(localDate(now));
    const start = startOfLocalDay(weekStart);
    const end = startOfLocalDay(addDays(weekStart, 7));
    const targetSessions = await this.settings.getNumber('streak.weekly_min_sessions');
    const candidates = await this.repo.warningCandidates(start, end, targetSessions);
    const lines: string[] = [];
    for (const candidate of candidates) {
      const sent = await this.notifications.notifyFromTemplate(
        candidate.memberId,
        NotificationEvent.STREAK_WARNING,
        {
          done: candidate.sessionsCount,
          target: targetSessions,
          missing: targetSessions - candidate.sessionsCount,
          streak: candidate.currentStreakWeeks,
        },
        { dedupeKey: `streak-warning:${candidate.memberId}:${weekStart}`, payload: { weekStart } },
      );
      lines.push(`${candidate.memberId}: ${sent ? 'WARNED' : 'SKIPPED'}`);
    }
    return lines;
  }

  private async closeMember(
    memberId: string,
    weekStart: string,
    start: Date,
    end: Date,
    now: Date,
  ): Promise<StreakResult | 'ALREADY_CLOSED'> {
    if (await this.repo.log(memberId, weekStart)) return 'ALREADY_CLOSED';
    const member = await this.repo.member(memberId, true);
    if (!member || (await this.repo.log(memberId, weekStart))) return 'ALREADY_CLOSED';
    const [sessionsCount, targetSessions, freezeEveryWeeks, maxFreezePerMonth] = await Promise.all([
      this.repo.countConfirmedSessions(memberId, start, end),
      this.settings.getNumber('streak.weekly_min_sessions'),
      this.settings.getNumber('streak.freeze_every_weeks'),
      this.settings.getNumber('streak.max_freeze_per_month'),
    ]);
    const before = member.currentStreakWeeks;
    let result: StreakResult = 'SKIPPED';
    let after = before;
    let freezeGrantId: string | null = null;
    if (sessionsCount >= targetSessions) {
      result = 'INCREASED';
      after = before + 1;
    } else if (before > 0 && maxFreezePerMonth > 0) {
      const month = monthStartOf(weekStart);
      const nextMonth = addMonthsToDate(month, 1);
      freezeGrantId = await this.repo.claimFreeze(
        memberId,
        now,
        startOfLocalDay(month),
        startOfLocalDay(nextMonth),
        maxFreezePerMonth,
      );
      if (freezeGrantId) {
        await this.repo.useFreeze(freezeGrantId, weekStart, now);
        result = 'FROZEN';
      } else {
        result = 'RESET';
        after = 0;
      }
    } else if (before > 0) {
      result = 'RESET';
      after = 0;
    }
    const startedWeek = after === 0 ? null : (member.streakStartedWeek ?? weekStart);
    await this.repo.updateMember(memberId, after, Math.max(member.longestStreakWeeks, after), startedWeek);
    await this.repo.insertLog({
      memberId,
      weekStart,
      sessionsCount,
      targetSessions,
      result,
      streakBefore: before,
      streakAfter: after,
      freezeGrantId,
    });
    if (result === 'INCREASED') {
      const milestones = await this.settings.get<Record<string, unknown>>('streak.milestones');
      const dp = Number(milestones[String(after)] ?? 0);
      if (Number.isInteger(dp) && dp > 0)
        await this.points.award({
          memberId,
          source: 'STREAK_MILESTONE',
          dp,
          note: `Mốc chuỗi tập ${after} tuần`,
          idempotencyKey: `streak:${memberId}:${weekStart}:${after}`,
        });
      if (after % freezeEveryWeeks === 0)
        await this.repo.grantMonthlyFreeze(
          memberId,
          monthStartOf(weekStart),
          startOfLocalDay(addMonthsToDate(monthStartOf(weekStart), 1)),
        );
    }
    await this.audit.record({
      actorId: null,
      action: 'STREAK_WEEK_CLOSED',
      entityType: 'MEMBER',
      entityId: memberId,
      before: { streak: before },
      after: { streak: after, result, sessionsCount, targetSessions, freezeGrantId },
    });
    await eventBus.emit(DomainEvents.STREAK_WEEK_CLOSED, {
      memberId,
      weekStart,
      result,
      streakBefore: before,
      streakAfter: after,
    });
    return result;
  }
}
