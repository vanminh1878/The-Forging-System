import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { addDays, startOfLocalDay } from '../../src/common/utils/time';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('STK-01..05 weekly streaks', () => {
  let ctx: TestContext;
  let member: { userId: string; token: string };
  let coachId: string;
  const weekStart = '2026-11-23';
  const closeAt = new Date('2026-11-30T00:05:00+07:00');

  beforeAll(async () => {
    ctx = await bootTestApp();
    coachId = (await createStaff({ role: 'COACH', fullName: 'Streak coach', phone: nextPhone() })).userId;
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
           SELECT $1,$2,id,'REGULAR',$3,$4,$4+interval '1 hour','COMPLETED' FROM branches WHERE code='Q1'`,
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

  it('awards the configured four-week milestone idempotently', async () => {
    await confirmed([1, 3, 5]);
    await ctx.tx(() =>
      sql.exec(
        'UPDATE members SET current_streak_weeks=3,longest_streak_weeks=3,streak_started_week=$2 WHERE user_id=$1',
        [member.userId, '2026-11-02'],
      ),
    );
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
  });
});
