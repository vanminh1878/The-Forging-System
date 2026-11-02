import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';
import { DomainEvents, eventBus } from '../../src/common/events/event-bus';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';

// Monday 2026-03-02 10:00 local = 03:00Z (UTC+7).
const NOW = new Date('2026-03-02T03:00:00Z');

describe('classes: CLS-03 one-off, exam and cancelled sessions', () => {
  let ctx: TestContext;
  let admin: string;
  let reception: string;
  let memberToken: string;
  let memberId: string;
  let coachA: string;
  let coachAId: string;
  let coachB: string;
  let coachBId: string;
  let q1: string;
  let classId: string;

  const post = (path: string, token: string, b: object = {}) => ctx.api.post(`/api/v1${path}`).set(bearer(token)).send(b);
  const body = (over: Record<string, unknown> = {}) => ({
    sessionTypeCode: 'PT',
    branchId: q1,
    startsAt: '2026-03-03T11:00:00Z',
    durationMinutes: 60,
    title: 'PT 1-1',
    ...over,
  });
  const notifs = (userId: string, event: string) =>
    ownerQuery<{ title: string; body: string }>(`SELECT title, body FROM notifications WHERE user_id = $1 AND event_type = $2`, [userId, event]);

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(NOW));
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    admin = (await login(ctx.api, a.phone)).token;
    reception = (await login(ctx.api, (await createStaff({ role: 'RECEPTIONIST', fullName: 'LT', phone: nextPhone() })).phone)).token;
    const ca = await createStaff({ role: 'COACH', fullName: 'Coach A', phone: nextPhone() });
    coachAId = ca.userId;
    coachA = (await login(ctx.api, ca.phone)).token;
    const cb = await createStaff({ role: 'COACH', fullName: 'Coach B', phone: nextPhone() });
    coachBId = cb.userId;
    coachB = (await login(ctx.api, cb.phone)).token;
    const m = await registerMember(ctx.api);
    memberToken = m.token;
    memberId = m.userId;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    const c = await post('/admin/classes', admin, {
      branchId: q1,
      name: 'Boxing tối',
      sessionTypeCode: 'GROUP',
      weekdays: [1, 3],
      startTime: '18:30',
      durationMinutes: 60,
      defaultCoachId: coachAId,
    });
    classId = c.body.data.id;
  });
  afterAll(() => resetClock());

  describe('POST /sessions', () => {
    it('401 / 403 for anonymous, learner and receptionist', async () => {
      expect((await ctx.api.post('/api/v1/sessions').send(body())).status).toBe(401);
      expect((await post('/sessions', memberToken, body())).status).toBe(403);
      expect((await post('/sessions', reception, body())).status).toBe(403);
    });

    it('400 on invalid payload', async () => {
      expect((await post('/sessions', coachA, body({ durationMinutes: 10 }))).body.error.code).toBe('VALIDATION_ERROR');
      expect((await post('/sessions', coachA, body({ startsAt: 'tomorrow' }))).status).toBe(400);
      expect((await post('/sessions', coachA, body({ memberIds: ['x'] }))).status).toBe(400);
    });

    it('coach creates a PT with learners; the learner sees it in /me/schedule', async () => {
      const res = await post('/sessions', coachA, body({ memberIds: [memberId, memberId] }));
      expect(res.status).toBe(201);
      expect(res.body.data).toMatchObject({ coachId: coachAId, status: 'SCHEDULED', isExam: false, attendeeCount: 1, classId: null });
      const sched = await ctx.api.get('/api/v1/me/schedule?date=2026-03-03').set(bearer(memberToken));
      expect(sched.body.data.map((i: { title: string }) => i.title)).toContain('PT 1-1');
      const a = await ownerQuery<{ attendance_status: string }>(`SELECT attendance_status FROM attendances WHERE session_id = $1`, [res.body.data.id]);
      expect(a).toEqual([{ attendance_status: 'UPCOMING' }]);
      const audit = await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'SESSION_CREATED' AND entity_type = 'SESSION' AND entity_id = $1`, [res.body.data.id]);
      expect(audit).toHaveLength(1);
    });

    it('409 when the coach already has an overlapping session; adjacent is fine', async () => {
      const r = await post('/sessions', coachA, body({ startsAt: '2026-03-03T11:30:00Z' }));
      expect(r.status).toBe(409);
      expect(r.body.error.code).toBe('COACH_SESSION_OVERLAP');
      expect((await post('/sessions', coachA, body({ startsAt: '2026-03-03T12:00:00Z', title: 'Sau' }))).status).toBe(201);
    });

    it('422 for a session in the past or exactly now; one minute later is ok', async () => {
      const past = await post('/sessions', coachA, body({ startsAt: NOW.toISOString() }));
      expect(past.status).toBe(422);
      expect(past.body.error.code).toBe('SESSION_IN_PAST');
      expect((await post('/sessions', coachA, body({ startsAt: '2026-03-02T03:01:00Z', title: 'Gần' }))).status).toBe(201);
    });

    it('422 for an inactive / unknown session type', async () => {
      expect((await post('/sessions', coachA, body({ sessionTypeCode: 'NOPE' }))).body.error.code).toBe('SESSION_TYPE_INACTIVE');
    });

    it('maxDpOverride must be inside [max_dp, max_dp_upper]; types without an upper bound cannot override', async () => {
      const t = body({ sessionTypeCode: 'SPARRING', startsAt: '2026-03-04T05:00:00Z', title: 'Sparring' });
      const low = await post('/sessions', coachA, { ...t, maxDpOverride: 99 });
      expect(low.status).toBe(422);
      expect(low.body.error.code).toBe('MAX_DP_OUT_OF_RANGE');
      expect((await post('/sessions', coachA, { ...t, maxDpOverride: 151 })).status).toBe(422);
      const ok = await post('/sessions', coachA, { ...t, maxDpOverride: 150 });
      expect(ok.status).toBe(201);
      expect(ok.body.data.maxDpOverride).toBe(150);
      const noUpper = await post('/sessions', coachB, body({ startsAt: '2026-03-04T05:00:00Z', maxDpOverride: 65 }));
      expect(noUpper.body.error.code).toBe('MAX_DP_OUT_OF_RANGE');
    });

    it('403 NOT_YOUR_SESSION when a coach assigns someone else; admin may', async () => {
      const r = await post('/sessions', coachA, body({ coachId: coachBId, startsAt: '2026-03-05T05:00:00Z' }));
      expect(r.status).toBe(403);
      expect(r.body.error.code).toBe('NOT_YOUR_SESSION');
      const ok = await post('/sessions', admin, body({ coachId: coachBId, startsAt: '2026-03-05T05:00:00Z' }));
      expect(ok.status).toBe(201);
      expect(ok.body.data.coachId).toBe(coachBId);
      expect((await post('/sessions', admin, body({ coachId: memberId, startsAt: '2026-03-06T05:00:00Z' }))).body.error.code).toBe('COACH_INVALID');
    });

    it('400 when memberIds contains a non-member; 409 on a duplicate (class, startsAt)', async () => {
      const r = await post('/sessions', coachA, body({ startsAt: '2026-03-06T05:00:00Z', memberIds: [coachBId] }));
      expect(r.status).toBe(400);
      expect(r.body.error.code).toBe('MEMBER_NOT_FOUND');
      // class session Wed 2026-03-04 18:30 local = 11:30Z already generated for the class
      const dup = await post('/sessions', admin, body({ classId, startsAt: '2026-03-04T11:30:00Z', coachId: coachBId }));
      expect(dup.status).toBe(409);
      expect(dup.body.error.code).toBe('SESSION_ALREADY_EXISTS');
    });
  });

  describe('POST /classes/:id/exam-sessions', () => {
    const exam = (token: string, b: object, id = classId) => post(`/classes/${id}/exam-sessions`, token, b);
    let sessionId: string;

    beforeAll(async () => {
      await ownerQuery(
        `INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date) VALUES ($1, $2, $3, '2026-03-01')`,
        [ctx.tenantId, classId, memberId],
      );
    });

    it('401 / 403 / 400', async () => {
      expect((await ctx.api.post(`/api/v1/classes/${classId}/exam-sessions`).send({ date: '2026-03-04' })).status).toBe(401);
      expect((await exam(reception, { date: '2026-03-04' })).status).toBe(403);
      expect((await exam(memberToken, { date: '2026-03-04' })).status).toBe(403);
      expect((await exam(admin, { date: '2026-02-30' })).status).toBe(400);
      expect((await exam(admin, {})).status).toBe(400);
      expect((await exam(admin, { date: '2026-03-04' }, '00000000-0000-4000-8000-000000000000')).status).toBe(404);
    });

    it("another class's coach gets 403 NOT_YOUR_SESSION", async () => {
      const r = await exam(coachB, { date: '2026-03-04' });
      expect(r.status).toBe(403);
      expect(r.body.error.code).toBe('NOT_YOUR_SESSION');
    });

    it('marks the generated session as an exam and notifies the enrolled learner once', async () => {
      const res = await exam(coachA, { date: '2026-03-04' });
      expect(res.status).toBe(201);
      sessionId = res.body.data.id;
      expect(res.body.data).toMatchObject({ isExam: true, title: 'Kiểm tra — Boxing tối', classId });
      const rows = await ownerQuery(`SELECT 1 FROM sessions WHERE class_id = $1 AND starts_at = '2026-03-04T11:30:00Z'`, [classId]);
      expect(rows).toHaveLength(1);
      const n = await notifs(memberId, 'EXAM');
      expect(n).toEqual([{ title: 'BUỔI KIỂM TRA MỚI', body: 'Kiểm tra — Boxing tối — 04/03/2026 18:30.' }]);
      await exam(coachA, { date: '2026-03-04', title: 'Đổi tên' });
      expect(await notifs(memberId, 'EXAM')).toHaveLength(1);
      const audit = await ownerQuery<{ reason: string }>(`SELECT reason FROM audit_logs WHERE action = 'EXAM_CREATED' AND entity_id = $1`, [sessionId]);
      expect(audit[0].reason).toBe('Boxing tối · 04/03/2026');
    });

    it('creates a new session when none exists (a Saturday, outside the weekly schedule)', async () => {
      const res = await exam(admin, { date: '2026-03-07', title: 'Thi lên đai' });
      expect(res.status).toBe(201);
      expect(res.body.data).toMatchObject({ isExam: true, title: 'Thi lên đai', coachId: coachAId });
      expect(new Date(res.body.data.startsAt).toISOString()).toBe('2026-03-07T11:30:00.000Z');
    });

    it('422 for a past slot (same-day start already passed) and an inactive class; 409 when the coach is busy', async () => {
      setClock(fixedClock(new Date('2026-03-02T11:30:00Z'))); // exactly Monday 18:30 local
      const past = await exam(admin, { date: '2026-03-02' });
      expect(past.status).toBe(422);
      expect(past.body.error.code).toBe('SESSION_IN_PAST');
      setClock(fixedClock(NOW));
      await ownerQuery(`INSERT INTO sessions (tenant_id, branch_id, session_type_code, coach_id, starts_at, ends_at)
        VALUES ($1, $2, 'PT', $3, '2026-03-10T11:00:00Z', '2026-03-10T12:00:00Z')`, [ctx.tenantId, q1, coachAId]);
      const busy = await exam(admin, { date: '2026-03-10' });
      expect(busy.status).toBe(409);
      expect(busy.body.error.code).toBe('COACH_SESSION_OVERLAP');
      const c2 = await post('/admin/classes', admin, { branchId: q1, name: 'Tắt', sessionTypeCode: 'GROUP', weekdays: [1], startTime: '09:00', durationMinutes: 60, isActive: false });
      expect((await exam(admin, { date: '2026-03-09' }, c2.body.data.id)).body.error.code).toBe('CLASS_INACTIVE');
    });
  });

  describe('POST /sessions/:id/cancel', () => {
    const cancel = (token: string, id: string, b: object = { reason: 'Nghỉ lễ' }) => post(`/sessions/${id}/cancel`, token, b);
    const runJob = () => ctx.api.post('/api/v1/admin/batch-jobs/sessions/run').set(bearer(admin));
    let fri: string;

    beforeAll(async () => {
      fri = (await ownerQuery<{ id: string }>(`SELECT id FROM sessions WHERE class_id = $1 AND starts_at = '2026-03-16T11:30:00Z'`, [classId]))[0].id;
    });

    it('401 / 403 / 400 / 404', async () => {
      expect((await ctx.api.post(`/api/v1/sessions/${fri}/cancel`).send({ reason: 'x' })).status).toBe(401);
      expect((await cancel(reception, fri)).status).toBe(403);
      expect((await cancel(memberToken, fri)).status).toBe(403);
      for (const b of [{}, { reason: '' }, { reason: '   ' }]) {
        const r = await cancel(admin, fri, b);
        expect(r.status).toBe(400);
        expect(r.body.error.code).toBe('CANCEL_REASON_REQUIRED');
      }
      expect((await cancel(admin, '00000000-0000-4000-8000-000000000000')).status).toBe(404);
    });

    it("a coach cannot cancel another coach's session", async () => {
      const r = await cancel(coachB, fri);
      expect(r.status).toBe(403);
      expect(r.body.error.code).toBe('NOT_YOUR_SESSION');
    });

    it('cancels, notifies learners, emits the event, and the generator does not recreate it', async () => {
      const seen: string[] = [];
      eventBus.on<{ sessionId: string }>(DomainEvents.SESSION_CANCELLED, (e) => void seen.push(e.sessionId));
      const res = await cancel(coachA, fri, { reason: 'Nghỉ lễ' });
      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('CANCELLED');
      const n = await notifs(memberId, 'SESSION_CANCELLED');
      expect(n).toEqual([{ title: 'BUỔI TẬP BỊ HUỶ', body: 'Boxing tối 18:30 16/03 đã huỷ. Lý do: Nghỉ lễ.' }]);
      await new Promise((r) => setTimeout(r, 50));
      expect(seen).toEqual([fri]);
      const audit = await ownerQuery<{ reason: string }>(`SELECT reason FROM audit_logs WHERE action = 'SESSION_CANCELLED' AND entity_id = $1`, [fri]);
      expect(audit[0].reason).toBe('Nghỉ lễ');

      setClock(fixedClock(new Date('2026-03-02T04:00:00Z')));
      await runJob();
      const rows = await ownerQuery<{ status: string }>(`SELECT status FROM sessions WHERE class_id = $1 AND starts_at = '2026-03-16T11:30:00Z'`, [classId]);
      expect(rows).toEqual([{ status: 'CANCELLED' }]);
      setClock(fixedClock(NOW));
    });

    it('409 when already cancelled, completed, or already started', async () => {
      const again = await cancel(admin, fri);
      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('SESSION_NOT_CANCELLABLE');
      const wed = (await ownerQuery<{ id: string }>(`SELECT id FROM sessions WHERE class_id = $1 AND starts_at = '2026-03-18T11:30:00Z'`, [classId]))[0].id;
      setClock(fixedClock(new Date('2026-03-18T11:30:00Z'))); // exactly at the start
      expect((await cancel(admin, wed)).status).toBe(409);
      setClock(fixedClock(new Date('2026-03-18T11:29:59Z')));
      expect((await cancel(admin, wed)).status).toBe(200);
      setClock(fixedClock(NOW));
    });
  });
});
