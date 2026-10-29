import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  bearer,
  bootTestApp,
  createStaff,
  login,
  nextPhone,
  ownerQuery,
  registerMember,
} from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';

// Wed 2026-03-04 12:00 local (UTC+7).
const NOW = new Date('2026-03-04T05:00:00Z');

describe('schedule: CLS-04 learner week/month view', () => {
  let ctx: TestContext;
  let me: string;
  let myId: string;
  let otherToken: string;
  let coachToken: string;
  let coachId: string;
  let q1: string;
  let q7: string;
  const ids: Record<string, string> = {};

  const get = (qs = '', t = me) => ctx.api.get(`/api/v1/me/schedule${qs}`).set(bearer(t));
  const titles = (res: { body: { data: Array<{ title: string }> } }) => res.body.data.map((i) => i.title);

  async function cls(name: string, branchId: string) {
    return (
      await ownerQuery<{ id: string }>(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes)
         VALUES ($1, $2, $3, 'GROUP', '{1}', '18:30', 60) RETURNING id`,
        [ctx.tenantId, branchId, name],
      )
    )[0].id;
  }
  async function enroll(
    classId: string,
    memberId: string,
    start: string,
    end: string | null,
    status = 'ACTIVE',
  ) {
    await ownerQuery(
      `INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date, end_date, status) VALUES ($1, $2, $3, $4, $5, $6)`,
      [ctx.tenantId, classId, memberId, start, end, status],
    );
  }
  async function session(
    key: string,
    classId: string | null,
    branchId: string,
    startsAt: string,
    over: { status?: string; lessonPlanId?: string; notes?: string } = {},
  ) {
    const start = new Date(startsAt);
    ids[key] = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at, status, lesson_plan_id, notes)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $6, $7, $8, $9, $10) RETURNING id`,
        [
          ctx.tenantId,
          classId,
          branchId,
          coachId,
          key,
          start,
          new Date(start.getTime() + 3_600_000),
          over.status ?? 'SCHEDULED',
          over.lessonPlanId ?? null,
          over.notes ?? null,
        ],
      )
    )[0].id;
  }
  async function attend(key: string, memberId: string, status: string, extra = '') {
    await ownerQuery(
      `INSERT INTO attendances (tenant_id, session_id, member_id, attendance_status ${extra ? ', ' + extra.split('=')[0] : ''})
       VALUES ($1, $2, $3, $4 ${extra ? ', ' + extra.split('=')[1] : ''})`,
      [ctx.tenantId, ids[key], memberId, status],
    );
  }

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(NOW));
    const m = await registerMember(ctx.api);
    me = m.token;
    myId = m.userId;
    const o = await registerMember(ctx.api);
    otherToken = o.token;
    const c = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    coachId = c.userId;
    coachToken = (await login(ctx.api, c.phone)).token;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    q7 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q7'`))[0].id;

    const c1 = await cls('C1', q1);
    const c2 = await cls('C2 not mine', q1);
    const c3 = await cls('C3 ends 5 Mar', q1);
    const c4 = await cls('C4 cancelled enrollment', q1);
    await enroll(c1, myId, '2026-03-01', null);
    await enroll(c3, myId, '2026-03-01', '2026-03-05', 'ENDED');
    await enroll(c4, myId, '2026-03-01', null, 'CANCELLED');
    await enroll(c1, o.userId, '2026-03-01', null);

    // Enrolled class C1 (week of Mon 2 .. Sun 8 March).
    await session('Mon past', c1, q1, '2026-03-02T11:30:00Z'); // no attendance and ended -> ABSENT
    await session('Wed today', c1, q1, '2026-03-04T10:00:00Z'); // 17:00 local, upcoming, today
    await session('Fri cancelled', c1, q1, '2026-03-06T11:30:00Z', { status: 'CANCELLED' });
    await session('Sun 23:59', c1, q1, '2026-03-08T16:59:00Z'); // last minute of the week
    await session('Mon next 00:00', c1, q1, '2026-03-08T17:00:00Z'); // first minute of next week
    await session('Before enrollment', c1, q1, '2026-02-28T11:30:00Z');
    await session('Month end 23:59', c1, q1, '2026-03-31T16:59:00Z');
    await session('Next month', c1, q1, '2026-03-31T17:00:00Z');
    // Other classes.
    await session('Other class', c2, q1, '2026-03-03T11:30:00Z');
    await session('C3 in', c3, q1, '2026-03-05T11:30:00Z');
    await session('C3 after end', c3, q1, '2026-03-06T11:30:00Z');
    await session('C4 cancelled enrollment', c4, q1, '2026-03-05T12:00:00Z');
    // Ad hoc sessions (no class) with an attendance row, in another branch.
    await session('Tue awaiting', null, q7, '2026-03-03T03:00:00Z');
    await session('Thu pass', null, q7, '2026-03-05T03:00:00Z');
    await session('Sat fail', null, q7, '2026-03-07T03:00:00Z');
    await session('Mon absent', null, q7, '2026-03-02T03:00:00Z');
    await session('Sat upcoming', null, q7, '2026-03-07T08:00:00Z');
    await attend('Tue awaiting', myId, 'AWAITING_COACH', "checkin_at='2026-03-03T02:50:00Z'");
    await attend('Thu pass', myId, 'CONFIRMED_PASS', 'completion_percent=100');
    await attend('Sat fail', myId, 'CONFIRMED_FAIL');
    await attend('Mon absent', myId, 'ABSENT');
    await attend('Sat upcoming', myId, 'UPCOMING');
    await attend('Other class', o.userId, 'CONFIRMED_PASS');
  });
  afterAll(() => resetClock());

  it('requires a learner token', async () => {
    expect((await ctx.api.get('/api/v1/me/schedule')).status).toBe(401);
    expect((await get('', coachToken)).status).toBe(403);
    expect(
      (
        await ctx.api
          .get(`/api/v1/me/sessions/${'0'.repeat(8)}-0000-4000-8000-000000000000`)
          .set(bearer(coachToken))
      ).status,
    ).toBe(403);
    expect(
      (await ctx.api.get(`/api/v1/me/sessions/${'0'.repeat(8)}-0000-4000-8000-000000000000`)).status,
    ).toBe(401);
  });

  it('week view defaults to the current week (Mon-Sun) with every status derived', async () => {
    const res = await get();
    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ view: 'week', from: '2026-03-02', to: '2026-03-08' });
    expect(res.body.data.map((i: { title: string; status: string }) => [i.title, i.status])).toEqual([
      ['Mon absent', 'ABSENT'],
      ['Mon past', 'ABSENT'],
      ['Tue awaiting', 'AWAITING_COACH'],
      ['Wed today', 'UPCOMING'],
      ['Thu pass', 'CONFIRMED_PASS'],
      ['C3 in', 'UPCOMING'],
      ['Fri cancelled', 'CANCELLED'],
      ['Sat fail', 'CONFIRMED_FAIL'],
      ['Sat upcoming', 'UPCOMING'],
      ['Sun 23:59', 'UPCOMING'],
    ]);
    const today = res.body.data.find((i: { title: string }) => i.title === 'Wed today');
    expect(today).toMatchObject({
      sessionId: ids['Wed today'],
      sessionType: 'GROUP',
      isExam: false,
      date: '2026-03-04',
      isToday: true,
      branch: { id: q1, name: 'HVP Boxing - The Corner' },
      coach: { id: coachId, fullName: 'Coach' },
    });
    expect(res.body.data.filter((i: { isToday: boolean }) => i.isToday)).toHaveLength(1);
    const awaiting = res.body.data.find((i: { title: string }) => i.title === 'Tue awaiting');
    expect(awaiting.checkinAt).toBe('2026-03-03T02:50:00.000Z');
    expect(res.body.data.find((i: { title: string }) => i.title === 'Thu pass').completionPercent).toBe(100);
  });

  it('week boundaries: Sunday 23:59 local is in, Monday 00:00 local starts the next week', async () => {
    const next = await get('?date=2026-03-09');
    expect(next.body.meta).toEqual({ view: 'week', from: '2026-03-09', to: '2026-03-15' });
    expect(titles(next)).toEqual(['Mon next 00:00']);
    const sun = await get('?date=2026-03-08');
    expect(sun.body.meta.from).toBe('2026-03-02');
    expect(titles(sun)).toContain('Sun 23:59');
    expect(titles(sun)).not.toContain('Mon next 00:00');
  });

  it('month view covers the calendar month and respects enrollment start date', async () => {
    const res = await get('?view=month&date=2026-03-15');
    expect(res.body.meta).toEqual({ view: 'month', from: '2026-03-01', to: '2026-03-31' });
    const t = titles(res);
    expect(t).toContain('Month end 23:59');
    expect(t).toContain('Mon next 00:00');
    expect(t).not.toContain('Next month');
    expect(t).not.toContain('Before enrollment');
    const apr = await get('?view=month&date=2026-04-10');
    expect(titles(apr)).toEqual(['Next month']);
    const feb = await get('?view=month&date=2026-02-10');
    expect(feb.body.meta.to).toBe('2026-02-28');
    expect(titles(feb)).toEqual([]);
  });

  it('hides other classes, ended enrollments past their end date and cancelled enrollments', async () => {
    const t = titles(await get());
    for (const hidden of ['Other class', 'C3 after end', 'C4 cancelled enrollment'])
      expect(t).not.toContain(hidden);
    expect(t).toContain('C3 in');
  });

  it('filters by branch and by derived status', async () => {
    expect(titles(await get(`?branchId=${q7}`))).toEqual([
      'Mon absent',
      'Tue awaiting',
      'Thu pass',
      'Sat fail',
      'Sat upcoming',
    ]);
    expect(titles(await get('?branchId=00000000-0000-4000-8000-000000000000'))).toEqual([]);
    expect(titles(await get('?status=ABSENT'))).toEqual(['Mon absent', 'Mon past']);
    expect(titles(await get('?status=CANCELLED'))).toEqual(['Fri cancelled']);
    expect(titles(await get('?status=UPCOMING'))).toEqual([
      'Wed today',
      'C3 in',
      'Sat upcoming',
      'Sun 23:59',
    ]);
    expect(titles(await get(`?status=CONFIRMED_PASS&branchId=${q1}`))).toEqual([]);
  });

  it('rejects invalid query values', async () => {
    for (const qs of [
      '?date=2026-02-30',
      '?date=04-03-2026',
      '?view=year',
      '?status=NOPE',
      '?branchId=abc',
    ]) {
      const res = await get(qs);
      expect([qs, res.status, res.body.error.code]).toEqual([qs, 400, 'VALIDATION_ERROR']);
    }
  });

  it('shows a session detail with lesson plan and notes; other learners get 404', async () => {
    const course = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO courses (tenant_id, code, name, duration_weeks, total_lessons) VALUES ($1, 'T', 'Test', 4, 8) RETURNING id`,
        [ctx.tenantId],
      )
    )[0].id;
    const lp = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO lesson_plans (tenant_id, course_id, lesson_no, title) VALUES ($1, $2, 1, 'JAB (1)') RETURNING id`,
        [ctx.tenantId, course],
      )
    )[0].id;
    await ownerQuery(`UPDATE sessions SET lesson_plan_id = $2, notes = 'Mang băng tay' WHERE id = $1`, [
      ids['Wed today'],
      lp,
    ]);
    const res = await ctx.api.get(`/api/v1/me/sessions/${ids['Wed today']}`).set(bearer(me));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      sessionId: ids['Wed today'],
      status: 'UPCOMING',
      isToday: true,
      lessonPlan: { id: lp, title: 'JAB (1)' },
      notes: 'Mang băng tay',
    });
    const plain = await ctx.api.get(`/api/v1/me/sessions/${ids['Sun 23:59']}`).set(bearer(me));
    expect(plain.body.data).toMatchObject({ lessonPlan: null, notes: null });
    // Attended ad hoc session is visible; someone else's session is not.
    expect((await ctx.api.get(`/api/v1/me/sessions/${ids['Thu pass']}`).set(bearer(me))).status).toBe(200);
    expect((await ctx.api.get(`/api/v1/me/sessions/${ids['Thu pass']}`).set(bearer(otherToken))).status).toBe(
      404,
    );
    expect(
      (await ctx.api.get(`/api/v1/me/sessions/${ids['Before enrollment']}`).set(bearer(me))).status,
    ).toBe(404);
    expect((await ctx.api.get('/api/v1/me/sessions/not-a-uuid').set(bearer(me))).status).toBe(400);
  });
});
