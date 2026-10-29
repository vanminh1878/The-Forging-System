import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';

// Wed 2026-03-04 12:00 local (UTC+7).
const NOW = new Date('2026-03-04T05:00:00Z');

describe('schedule: CLS-05 coach API', () => {
  let ctx: TestContext;
  let coachA: string;
  let coachAId: string;
  let coachB: string;
  let coachBId: string;
  let head: string;
  let reception: string;
  let memberToken: string;
  let m1: string;
  let m2: string;
  let m3: string;
  let q1: string;
  let q7: string;
  let classId: string;
  let sessA: string; // Wed 18:30, class session of coach A
  let sessB: string; // coach B's session

  const get = (path: string, token = coachA) => ctx.api.get(`/api/v1${path}`).set(bearer(token));
  async function session(coachId: string, startsAt: string, title: string, branchId = q1, cls: string | null = null) {
    return (
      await ownerQuery<{ id: string }>(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $6, $6::timestamptz + interval '1 hour') RETURNING id`,
        [ctx.tenantId, cls, branchId, coachId, title, startsAt],
      )
    )[0].id;
  }
  const attend = (sid: string, mid: string, status: string, extra = '') =>
    ownerQuery(
      `INSERT INTO attendances (tenant_id, session_id, member_id, attendance_status ${extra ? ', ' + extra.split('=')[0] : ''})
       VALUES ($1, $2, $3, $4 ${extra ? ', ' + extra.split('=')[1] : ''})`,
      [ctx.tenantId, sid, mid, status],
    );

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(NOW));
    const a = await createStaff({ role: 'COACH', fullName: 'Coach A', phone: nextPhone() });
    coachAId = a.userId;
    coachA = (await login(ctx.api, a.phone)).token;
    const b = await createStaff({ role: 'COACH', fullName: 'Coach B', phone: nextPhone() });
    coachBId = b.userId;
    coachB = (await login(ctx.api, b.phone)).token;
    head = (await login(ctx.api, (await createStaff({ role: 'HEAD_COACH', fullName: 'Head', phone: nextPhone() })).phone)).token;
    reception = (await login(ctx.api, (await createStaff({ role: 'RECEPTIONIST', fullName: 'LT', phone: nextPhone() })).phone)).token;
    const r1 = await registerMember(ctx.api, { fullName: 'An' });
    memberToken = r1.token;
    m1 = r1.userId;
    m2 = (await registerMember(ctx.api, { fullName: 'Bình' })).userId;
    m3 = (await registerMember(ctx.api, { fullName: 'Chi' })).userId;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    q7 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code <> 'Q1' LIMIT 1`))[0].id;
    await ownerQuery(`UPDATE members SET home_branch_id = $2 WHERE user_id = $1`, [m1, q1]);
    await ownerQuery(`UPDATE members SET home_branch_id = $2 WHERE user_id = $1`, [m2, q7]);
    classId = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes, default_coach_id)
         VALUES ($1, $2, 'Boxing tối', 'GROUP', '{3}', '18:30', 60, $3) RETURNING id`,
        [ctx.tenantId, q1, coachAId],
      )
    )[0].id;
    await ownerQuery(`INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes, default_coach_id, is_active)
      VALUES ($1, $2, 'Tắt', 'GROUP', '{3}', '09:00', 60, $3, false)`, [ctx.tenantId, q1, coachAId]);
    // m1 enrolled (active), m2 has only an attendance row, m3 enrolled but the enrollment ended before the session.
    await ownerQuery(`INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date) VALUES ($1, $2, $3, '2026-03-01')`, [ctx.tenantId, classId, m1]);
    await ownerQuery(`INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date, end_date, status) VALUES ($1, $2, $3, '2026-02-01', '2026-03-01', 'ENDED')`, [ctx.tenantId, classId, m3]);
    sessA = await session(coachAId, '2026-03-04T11:30:00Z', 'Boxing tối', q1, classId);
    sessB = await session(coachBId, '2026-03-04T11:30:00Z', 'Của B');
    await attend(sessA, m2, 'CONFIRMED_PASS', 'checkin_at=now()');
  });
  afterAll(() => resetClock());

  it('401 / 403: anonymous, learner, receptionist', async () => {
    for (const p of ['/coach/classes', '/coach/sessions', `/coach/sessions/${sessA}/roster`]) {
      expect((await ctx.api.get(`/api/v1${p}`)).status).toBe(401);
      expect((await get(p, memberToken)).status).toBe(403);
      expect((await get(p, reception)).status).toBe(403);
    }
  });

  it('GET /coach/classes lists only my active classes with enrolledCount', async () => {
    const res = await get('/coach/classes');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([
      {
        id: classId,
        name: 'Boxing tối',
        branch: { id: q1, name: expect.any(String) },
        sessionType: 'GROUP',
        weekdays: [3],
        startTime: '18:30',
        durationMinutes: 60,
        enrolledCount: 1,
      },
    ]);
    expect((await get('/coach/classes', coachB)).body.data).toEqual([]);
    expect((await get('/coach/classes', head)).body.data).toEqual([]);
  });

  describe('GET /coach/sessions', () => {
    it('day view (default): today only, with counts, and never the other coach sessions', async () => {
      const res = await get('/coach/sessions');
      expect(res.status).toBe(200);
      expect(res.body.meta).toEqual({ view: 'day', from: '2026-03-04', to: '2026-03-04' });
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0]).toMatchObject({
        sessionId: sessA,
        classId,
        className: 'Boxing tối',
        sessionType: 'GROUP',
        isExam: false,
        status: 'SCHEDULED',
        date: '2026-03-04',
        isToday: true,
        lessonPlan: null,
        counts: { registered: 2, checkedIn: 1, reviewed: 1 },
      });
      expect((await get('/coach/sessions', coachB)).body.data.map((s: { sessionId: string }) => s.sessionId)).toEqual([sessB]);
    });

    it('counts follow inserted attendances', async () => {
      await attend(sessA, m3, 'AWAITING_COACH', 'checkin_at=now()');
      const [s] = (await get('/coach/sessions')).body.data;
      expect(s.counts).toEqual({ registered: 3, checkedIn: 2, reviewed: 1 });
    });

    it('week view runs Monday to Sunday, boundaries inclusive/exclusive', async () => {
      const mon0 = await session(coachAId, '2026-03-01T17:00:00Z', 'Mon 00:00 local'); // Mon 2 March 00:00 local
      const sun = await session(coachAId, '2026-03-08T16:59:00Z', 'Sun 23:59 local');
      const prevSun = await session(coachAId, '2026-03-01T16:59:00Z', 'Sun 1 March 23:59');
      const nextMon = await session(coachAId, '2026-03-08T17:00:00Z', 'Mon 9 March 00:00');
      const res = await get('/coach/sessions?view=week&date=2026-03-04');
      expect(res.body.meta).toEqual({ view: 'week', from: '2026-03-02', to: '2026-03-08' });
      const ids = res.body.data.map((s: { sessionId: string }) => s.sessionId);
      expect(ids).toContain(mon0);
      expect(ids).toContain(sun);
      expect(ids).toContain(sessA);
      expect(ids).not.toContain(prevSun);
      expect(ids).not.toContain(nextMon);
      expect((await get('/coach/sessions?view=day&date=2026-03-08')).body.data.map((s: { sessionId: string }) => s.sessionId)).toEqual([sun]);
    });

    it('400 for bad view or date', async () => {
      expect((await get('/coach/sessions?view=month')).status).toBe(400);
      expect((await get('/coach/sessions?date=2026-02-30')).status).toBe(400);
    });
  });

  describe('GET /coach/sessions/:id/roster', () => {
    it("404 for another coach's session, an unknown id; 400 for a bad filter", async () => {
      expect((await get(`/coach/sessions/${sessB}/roster`)).status).toBe(404);
      expect((await get(`/coach/sessions/${sessA}/roster`, coachB)).status).toBe(404);
      expect((await get(`/coach/sessions/${sessA}/roster`, head)).status).toBe(404);
      expect((await get('/coach/sessions/00000000-0000-4000-8000-000000000000/roster')).status).toBe(404);
      expect((await get(`/coach/sessions/${sessA}/roster?filter=x`)).status).toBe(400);
    });

    it('lists enrolled + attendance learners with status, otherBranch and counts', async () => {
      const res = await get(`/coach/sessions/${sessA}/roster`);
      expect(res.status).toBe(200);
      expect(res.body.meta.counts).toEqual({ all: 3, pending: 2, reviewed: 1 });
      const by = Object.fromEntries(res.body.data.map((r: { memberId: string }) => [r.memberId, r]));
      expect(Object.keys(by).sort()).toEqual([m1, m2, m3].sort());
      expect(by[m1]).toMatchObject({ fullName: 'An', status: 'UPCOMING', otherBranch: false, checkinAt: null, dpAwarded: 0 });
      expect(by[m1].rank).toEqual({ order: expect.any(Number), name: expect.any(String) });
      expect(by[m2]).toMatchObject({ fullName: 'Bình', status: 'CONFIRMED_PASS', otherBranch: true });
      expect(by[m2].checkinAt).not.toBeNull();
      expect(by[m3]).toMatchObject({ status: 'AWAITING_COACH' });
      expect(res.body.data.map((r: { fullName: string }) => r.fullName)).toEqual(['An', 'Bình', 'Chi']);
    });

    it('filters pending / reviewed', async () => {
      const names = async (f: string) => (await get(`/coach/sessions/${sessA}/roster?filter=${f}`)).body.data.map((r: { fullName: string }) => r.fullName);
      expect(await names('pending')).toEqual(['An', 'Chi']);
      expect(await names('reviewed')).toEqual(['Bình']);
      expect(await names('all')).toHaveLength(3);
    });

    it('enrollment coverage is by session date: an enrollment starting later does not count', async () => {
      await ownerQuery(`UPDATE class_enrollments SET start_date = '2026-03-05' WHERE member_id = $1 AND class_id = $2`, [m1, classId]);
      const res = await get(`/coach/sessions/${sessA}/roster`);
      expect(res.body.meta.counts.all).toBe(2);
    });
  });
});
