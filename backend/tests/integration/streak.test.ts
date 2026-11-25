import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { addDays, startOfLocalDay } from '../../src/common/utils/time';
import { sql } from '../../src/db/sql';
import { runJob } from '../../src/jobs/job.runner';
import { jobs } from '../../src/jobs/registry';
import { bearer, bootTestApp, createStaff, login, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('STK-01..05 weekly streaks', () => {
  let ctx: TestContext;
  let member: { userId: string; token: string };
  let coachId: string;
  let coachToken: string;
  const weekStart = '2026-11-23';
  const closeAt = new Date('2026-11-30T00:05:00+07:00');

  beforeAll(async () => {
    ctx = await bootTestApp();
    const coach = await createStaff({ role: 'COACH', fullName: 'Streak coach', phone: nextPhone() });
    coachId = coach.userId;
    coachToken = (await login(ctx.api, coach.phone)).token;
  });
  beforeEach(async () => {
    member = await registerMember(ctx.api);
  });

  async function confirmed(days: number[]) {
    await ctx.tx(async () => {
      for (const day of days) {
        const startsAt = startOfLocalDay(addDays(weekStart, day));
        const sessionId = randomUUID();
        await sql.exec(
          `INSERT INTO sessions (id,tenant_id,branch_id,session_type_code,coach_id,starts_at,ends_at,status)
           SELECT $1,$2,id,'GROUP',$3,$4::timestamptz,$4::timestamptz+interval '1 hour','COMPLETED'
           FROM branches WHERE code='Q1'`,
          [sessionId, ctx.tenantId, coachId, startsAt],
        );
        await sql.exec(
          `INSERT INTO attendances (tenant_id,session_id,member_id,attendance_status,confirmed_at,completed_on)
           VALUES ($1,$2,$3,'CONFIRMED_PASS',$4,$5)`,
          [ctx.tenantId, sessionId, member.userId, startsAt, addDays(weekStart, day)],
        );
      }
    });
  }

  it('counts only confirmed sessions, closes once, logs the week and exposes GET /me/streak', async () => {
    await confirmed([0, 2, 4]);
    const first = await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    const second = await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    expect(first).toContain(`${member.userId}: INCREASED`);
    expect(second).toContain(`${member.userId}: ALREADY_CLOSED`);
    const response = await ctx.api.get('/api/v1/me/streak').set(bearer(member.token));
    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({
      currentStreakWeeks: 1,
      longestStreakWeeks: 1,
      targetSessions: 3,
    });
    expect(response.body.data.logs[0]).toMatchObject({ weekStart, sessionsCount: 3, result: 'INCREASED' });
    expect((await ctx.api.get('/api/v1/me/streak')).status).toBe(401);
    expect((await ctx.api.get('/api/v1/me/streak').set(bearer(coachToken))).status).toBe(403);
  });

  it('excludes non-passing attendance from the weekly count', async () => {
    await confirmed([0, 2]);
    await ctx.tx(async () => {
      const startsAt = startOfLocalDay(addDays(weekStart, 4));
      const sessionId = randomUUID();
      await sql.exec(
        `INSERT INTO sessions (id,tenant_id,branch_id,session_type_code,coach_id,starts_at,ends_at,status)
         SELECT $1,$2,id,'GROUP',$3,$4::timestamptz,$4::timestamptz+interval '1 hour','COMPLETED'
         FROM branches WHERE code='Q1'`,
        [sessionId, ctx.tenantId, coachId, startsAt],
      );
      await sql.exec(
        `INSERT INTO attendances (tenant_id,session_id,member_id,attendance_status,confirmed_at,completed_on)
         VALUES ($1,$2,$3,'CONFIRMED_FAIL',$4,$5)`,
        [ctx.tenantId, sessionId, member.userId, startsAt, addDays(weekStart, 4)],
      );
    });

    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    expect((await ctx.tx(() => ctx.services.streak.summary(member.userId, closeAt))).logs[0]).toMatchObject({
      sessionsCount: 2,
      result: 'SKIPPED',
    });
  });

  it('automatically uses an available freeze before resetting the streak', async () => {
    await ctx.tx(() =>
      sql.exec(
        'UPDATE members SET current_streak_weeks=2,longest_streak_weeks=2,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-16'],
      ),
    );
    await ctx.tx(() =>
      sql.exec(
        `INSERT INTO streak_freeze_grants (tenant_id,member_id,grant_source,expires_at)
      VALUES ($1,$2,'ADMIN',$3)`,
        [ctx.tenantId, member.userId, new Date('2026-12-31T00:00:00+07:00')],
      ),
    );
    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    const summary = await ctx.tx(() => ctx.services.streak.summary(member.userId, closeAt));
    expect(summary.currentStreakWeeks).toBe(2);
    expect(summary.logs[0]).toMatchObject({ result: 'FROZEN', freezeGrantId: expect.any(String) });
    expect(summary.availableFreezes).toBe(0);
  });

  it('resets a streak when no freeze is available', async () => {
    await ctx.tx(() =>
      sql.exec(
        'UPDATE members SET current_streak_weeks=2,longest_streak_weeks=2,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-16'],
      ),
    );

    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    const summary = await ctx.tx(() => ctx.services.streak.summary(member.userId, closeAt));
    expect(summary.currentStreakWeeks).toBe(0);
    expect(summary.logs[0]).toMatchObject({ result: 'RESET', streakBefore: 2, streakAfter: 0 });
  });

  it('does not use an expired freeze', async () => {
    await ctx.tx(async () => {
      await sql.exec(
        'UPDATE members SET current_streak_weeks=2,longest_streak_weeks=2,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-16'],
      );
      await sql.exec(
        `INSERT INTO streak_freeze_grants (tenant_id,member_id,grant_source,expires_at)
         VALUES ($1,$2,'ADMIN',$3)`,
        [ctx.tenantId, member.userId, new Date('2026-11-23T00:00:00+07:00')],
      );
    });

    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    const summary = await ctx.tx(() => ctx.services.streak.summary(member.userId, closeAt));
    expect(summary.currentStreakWeeks).toBe(0);
    expect(summary.logs[0]).toMatchObject({ result: 'RESET', freezeGrantId: null });
  });

  it('resets after the monthly freeze-use quota is exhausted', async () => {
    await ctx.tx(async () => {
      await sql.exec(
        'UPDATE members SET current_streak_weeks=2,longest_streak_weeks=2,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-16'],
      );
      for (const usedAt of ['2026-11-03T00:00:00+07:00', '2026-11-10T00:00:00+07:00']) {
        await sql.exec(
          `INSERT INTO streak_freeze_grants (tenant_id,member_id,grant_source,used_week_start,used_at)
           VALUES ($1,$2,'ADMIN','2026-11-03',$3)`,
          [ctx.tenantId, member.userId, new Date(usedAt)],
        );
      }
      await sql.exec(
        `INSERT INTO streak_freeze_grants (tenant_id,member_id,grant_source,expires_at)
         VALUES ($1,$2,'ADMIN',$3)`,
        [ctx.tenantId, member.userId, new Date('2026-12-31T00:00:00+07:00')],
      );
    });

    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    const summary = await ctx.tx(() => ctx.services.streak.summary(member.userId, closeAt));
    expect(summary.currentStreakWeeks).toBe(0);
    expect(summary.logs[0]).toMatchObject({ result: 'RESET', freezeGrantId: null });
    expect(summary.availableFreezes).toBe(1);
  });

  it('awards the configured four-week milestone idempotently', async () => {
    await confirmed([1, 3, 5]);
    await ctx.tx(() =>
      sql.exec(
        'UPDATE members SET current_streak_weeks=3,longest_streak_weeks=3,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-02'],
      ),
    );
    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    await ctx.tx(() => ctx.services.streak.closePreviousWeek(closeAt));
    expect(
      await ctx.tx(() =>
        sql.scalar<number>(
          `SELECT sum(dp_amount)::int FROM point_transactions WHERE member_id=$1 AND source='STREAK_MILESTONE'`,
          [member.userId],
        ),
      ),
    ).toBe(20);
    expect(
      await ctx.tx(() =>
        sql.scalar<number>('SELECT count(*)::int FROM streak_freeze_grants WHERE member_id=$1', [
          member.userId,
        ]),
      ),
    ).toBe(1);
    expect(
      await ctx.tx(() =>
        sql.scalar<number>('SELECT count(*)::int FROM streak_logs WHERE member_id=$1 AND week_start=$2', [
          member.userId,
          weekStart,
        ]),
      ),
    ).toBe(1);
  });

  it('runs the weekly close through the registered batch job and records its audit', async () => {
    await confirmed([0, 2, 4]);
    const job = jobs.find(({ key }) => key === 'streak-weekly-close');
    expect(job).toMatchObject({ cron: '5 0 * * 1' });
    setClock(fixedClock(closeAt));
    try {
      const batchRun = await runJob(job!, ctx.tenantId, null, ctx.services.audit);
      expect(batchRun).toMatchObject({ batchKey: 'streak-weekly-close', status: 'SUCCESS' });
      expect(batchRun.resultLines).toContain(`${member.userId}: INCREASED`);
      expect(
        await ctx.tx(() =>
          sql.scalar<number>(
            `SELECT count(*)::int FROM audit_logs WHERE action='BATCH_RUN' AND entity_id=$1`,
            [batchRun.id],
          ),
        ),
      ).toBe(1);
    } finally {
      resetClock();
    }
  });
});
