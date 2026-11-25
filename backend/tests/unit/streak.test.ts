import { describe, expect, it, vi } from 'vitest';
import { StreakService } from '../../src/modules/streak/streak.service';
import type { StreakRepository } from '../../src/modules/streak/streak.repository';
import type { SettingsService } from '../../src/modules/settings/settings.service';
import type { PointsPort } from '../../src/modules/points/points.service';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { NotifierPort } from '../../src/modules/notifications/notification.service';

function build({ sessions = 3, streak = 0, freezeId = null as string | null } = {}) {
  const repo = {
    activeMemberIdsForWeek: vi.fn().mockResolvedValue(['member-1']),
    log: vi.fn().mockResolvedValue(null),
    member: vi.fn().mockResolvedValue({
      id: 'member-1',
      currentStreakWeeks: streak,
      longestStreakWeeks: streak,
      streakStartedWeek: streak ? '2026-11-02' : null,
    }),
    countConfirmedSessions: vi.fn().mockResolvedValue(sessions),
    warningCandidates: vi.fn().mockResolvedValue([]),
    claimFreeze: vi.fn().mockResolvedValue(freezeId),
    useFreeze: vi.fn().mockResolvedValue(1),
    updateMember: vi.fn().mockResolvedValue(1),
    insertLog: vi.fn().mockResolvedValue(1),
    grantMonthlyFreeze: vi.fn().mockResolvedValue(true),
    availableFreezes: vi.fn().mockResolvedValue(0),
    recentLogs: vi.fn().mockResolvedValue([]),
  };
  const settings = {
    getNumber: vi.fn(
      async (key: string) =>
        ({
          'streak.weekly_min_sessions': 3,
          'streak.freeze_every_weeks': 4,
          'streak.max_freeze_per_month': 2,
        })[key] ?? 0,
    ),
    get: vi.fn().mockResolvedValue({ '4': 20, '8': 40, '12': 80 }),
  };
  const points = { award: vi.fn().mockResolvedValue({ duplicate: false }) };
  const audit = { record: vi.fn().mockResolvedValue(undefined) };
  const notifications = { notifyFromTemplate: vi.fn().mockResolvedValue(true) };
  return {
    service: new StreakService(
      repo as unknown as StreakRepository,
      settings as unknown as SettingsService,
      points as unknown as PointsPort,
      audit as unknown as AuditService,
      notifications as unknown as NotifierPort,
    ),
    repo,
    points,
    notifications,
  };
}

describe('STK weekly close', () => {
  const monday = new Date('2026-11-30T00:05:00+07:00');

  it.each([
    [3, 4, 20],
    [7, 8, 40],
    [11, 12, 80],
  ])('increments, logs, grants a freeze and awards milestone week %i', async (before, after, dp) => {
    const { service, repo, points } = build({ streak: before });
    await expect(service.closePreviousWeek(monday)).resolves.toEqual(['member-1: INCREASED']);
    expect(repo.updateMember).toHaveBeenCalledWith('member-1', after, after, '2026-11-02');
    expect(repo.grantMonthlyFreeze).toHaveBeenCalledOnce();
    expect(points.award).toHaveBeenCalledWith(expect.objectContaining({ source: 'STREAK_MILESTONE', dp }));
  });

  it('uses an eligible freeze and preserves the streak before resetting', async () => {
    const { service, repo, points } = build({ sessions: 0, streak: 2, freezeId: 'freeze-1' });
    await expect(service.closePreviousWeek(monday)).resolves.toEqual(['member-1: FROZEN']);
    expect(repo.useFreeze).toHaveBeenCalledWith('freeze-1', '2026-11-23', monday);
    expect(repo.updateMember).toHaveBeenCalledWith('member-1', 2, 2, '2026-11-02');
    expect(points.award).not.toHaveBeenCalled();
  });

  it('warns each at-risk member once per local week with the remaining sessions', async () => {
    const { service, repo, notifications } = build();
    repo.warningCandidates.mockResolvedValue([
      { memberId: 'member-1', currentStreakWeeks: 5, sessionsCount: 1 },
    ]);

    await expect(service.warnAtRiskMembers(monday)).resolves.toEqual(['member-1: WARNED']);
    expect(notifications.notifyFromTemplate).toHaveBeenCalledWith(
      'member-1',
      'STREAK_WARNING',
      { done: 1, target: 3, missing: 2, streak: 5 },
      expect.objectContaining({ dedupeKey: 'streak-warning:member-1:2026-11-30' }),
    );
  });
});
