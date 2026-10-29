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
import { DomainEvents, eventBus } from '../../src/common/events/event-bus';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';

// 2026-03-02 is a Monday; 10:00Z = 17:00 in Asia/Ho_Chi_Minh (UTC+7).
const MON_1700 = new Date('2026-03-02T10:00:00Z');

describe('classes: CLS-02 session generation', () => {
  let ctx: TestContext;
  let admin: string;
  let adminId: string;
  let reception: string;
  let memberToken: string;
  let memberId: string;
  let coachA: string;
  let coachB: string;
  let q1: string;
  let classId: string;

  const body = (over: Record<string, unknown> = {}) => ({
    branchId: q1,
    name: 'Boxing tối',
    sessionTypeCode: 'GROUP',
    weekdays: [1, 3, 5],
    startTime: '18:30',
    durationMinutes: 60,
    ...over,
  });
  const createClass = (over: Record<string, unknown> = {}) =>
    ctx.api.post('/api/v1/admin/classes').set(bearer(admin)).send(body(over));
  const patch = (id: string, b: object) =>
    ctx.api.patch(`/api/v1/admin/classes/${id}`).set(bearer(admin)).send(b);
  const runJob = () => ctx.api.post('/api/v1/admin/batch-jobs/sessions/run').set(bearer(admin));
  const sessions = (id: string, status?: string) =>
    ownerQuery<{ id: string; starts_at: Date; status: string; coach_id: string }>(
      `SELECT id, starts_at, status, coach_id FROM sessions WHERE class_id = $1 ${status ? `AND status = '${status}'` : ''} ORDER BY starts_at`,
      [id],
    );

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(MON_1700));
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminId = a.userId;
    admin = (await login(ctx.api, a.phone)).token;
    const r = await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() });
    reception = (await login(ctx.api, r.phone)).token;
    coachA = (await createStaff({ role: 'COACH', fullName: 'Coach A', phone: nextPhone() })).userId;
    coachB = (await createStaff({ role: 'COACH', fullName: 'Coach B', phone: nextPhone() })).userId;
    const m = await registerMember(ctx.api);
    memberToken = m.token;
    memberId = m.userId;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
  });
  afterAll(() => resetClock());

  it('generates sessions when a class is created: 28-day horizon, 18:30 local = 11:30Z', async () => {
    const res = await createClass({ defaultCoachId: coachA, capacity: 15 });
    expect(res.status).toBe(201);
    classId = res.body.data.id;
    const rows = await sessions(classId);
    // Mon 2, Wed 4, Fri 6 ... through Mon 30 March (day 28 is inclusive) = 13 sessions.
    expect(rows).toHaveLength(13);
    expect(rows[0].starts_at.toISOString()).toBe('2026-03-02T11:30:00.000Z');
    expect(rows[12].starts_at.toISOString()).toBe('2026-03-30T11:30:00.000Z');
    const [s] = await ownerQuery(
      `SELECT title, capacity, ends_at, is_exam, created_by, coach_id, branch_id FROM sessions WHERE id = $1`,
      [rows[0].id],
    );
    expect(s).toMatchObject({
      title: 'Boxing tối',
      capacity: 15,
      is_exam: false,
      created_by: null,
      coach_id: coachA,
      branch_id: q1,
    });
    expect((s.ends_at as Date).toISOString()).toBe('2026-03-02T12:30:00.000Z');
  });

  it('is idempotent and extends the window day by day (horizon boundary)', async () => {
    const first = await runJob();
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({
      status: 'SUCCESS',
      batchKey: 'sessions',
      resultLines: ['Không có buổi mới cần sinh.'],
    });
    expect(await sessions(classId)).toHaveLength(13);
    // Tue 3 March: 31 March is a Tuesday, nothing new. Wed 4 March: 1 April (Wed) enters the window.
    setClock(fixedClock(new Date('2026-03-03T10:00:00Z')));
    expect((await runJob()).body.data.resultLines).toEqual(['Không có buổi mới cần sinh.']);
    setClock(fixedClock(new Date('2026-03-04T03:00:00Z')));
    expect((await runJob()).body.data.resultLines).toEqual(['Lớp Boxing tối: +1 buổi']);
    expect(await sessions(classId)).toHaveLength(14);
    expect((await runJob()).body.data.resultLines).toEqual(['Không có buổi mới cần sinh.']);
    setClock(fixedClock(MON_1700));
  });

  it('skips sessions already past today and honours classes.session_horizon_days', async () => {
    await ctx.tx(() => ctx.services.settings.set('classes.session_horizon_days', 7, adminId));
    setClock(fixedClock(new Date('2026-03-02T23:00:00Z'))); // Tue 3 March 06:00 local = exactly the class start
    const res = await createClass({
      name: 'Sáng',
      weekdays: [1, 2, 3, 4, 5, 6, 7],
      startTime: '06:00',
      defaultCoachId: coachA,
    });
    const rows = await sessions(res.body.data.id);
    // Start 3 March 06:00 is not before "now" (kept); offsets 0..7 give 3..10 March = 8 days.
    expect(rows).toHaveLength(8);
    expect(rows[0].starts_at.toISOString()).toBe('2026-03-02T23:00:00.000Z');
    await ctx.tx(() => ctx.services.settings.set('classes.session_horizon_days', 28, adminId));
    setClock(fixedClock(MON_1700));
  });

  it('skips a class without a default coach', async () => {
    const res = await createClass({ name: 'Không coach' });
    expect(res.status).toBe(201);
    expect(await sessions(res.body.data.id)).toHaveLength(0);
    const run = await runJob();
    expect(run.body.data.resultLines).toContain('Lớp Không coach chưa có coach mặc định — bỏ qua.');
  });

  it('a duplicate (class, start) is rejected by the unique index unless the first is cancelled', async () => {
    const [first] = await sessions(classId);
    const dup = () =>
      ownerQuery(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, starts_at, ends_at)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $5)`,
        [ctx.tenantId, classId, q1, coachA, first.starts_at],
      );
    await expect(dup()).rejects.toThrow(/ux_sessions_class_start/);
  });

  it('changing the schedule deletes untouched sessions and cancels those with attendance', async () => {
    expect(await sessions(classId)).toHaveLength(14);
    const friday = (await sessions(classId)).find(
      (x) => x.starts_at.toISOString() === '2026-03-13T11:30:00.000Z',
    )!;
    await ownerQuery(`INSERT INTO attendances (tenant_id, session_id, member_id) VALUES ($1, $2, $3)`, [
      ctx.tenantId,
      friday.id,
      memberId,
    ]);
    const cancelled: string[] = [];
    eventBus.on<{ sessionId: string }>(
      DomainEvents.SESSION_CANCELLED,
      (e) => void cancelled.push(e.sessionId),
    );

    expect((await patch(classId, { weekdays: [1, 3] })).status).toBe(200);
    // 3 other Fridays removed; the Friday with attendance is kept but CANCELLED.
    expect(await sessions(classId)).toHaveLength(11);
    const c = await sessions(classId, 'CANCELLED');
    expect(c.map((x) => x.id)).toEqual([friday.id]);
    await new Promise((r) => setTimeout(r, 50));
    expect(cancelled).toEqual([friday.id]);
    const audit = await ownerQuery<{ after_data: Record<string, number> }>(
      `SELECT after_data FROM audit_logs WHERE action = 'CLASS_SESSIONS_SYNCED' AND entity_id = $1 AND actor_id = $2 ORDER BY created_at DESC`,
      [classId, adminId],
    );
    expect(audit[0].after_data).toMatchObject({ generated: 0, deleted: 3, cancelled: 1 });

    // A new start time replaces every future scheduled session (19:00 local = 12:00Z).
    expect((await patch(classId, { startTime: '19:00' })).status).toBe(200);
    const scheduled = await sessions(classId, 'SCHEDULED');
    // The 1 April session generated earlier is beyond today's 28-day window, so it is not recreated.
    expect(scheduled).toHaveLength(9);
    expect(scheduled[0].starts_at.toISOString()).toBe('2026-03-02T12:00:00.000Z');
    // Renaming alone does not touch sessions.
    const before = (await sessions(classId)).map((x) => x.id);
    await patch(classId, { name: 'Boxing tối mới' });
    expect((await sessions(classId)).map((x) => x.id)).toEqual(before);
  });

  it('changing the default coach moves future scheduled sessions only', async () => {
    expect((await patch(classId, { defaultCoachId: coachB })).status).toBe(200);
    expect((await sessions(classId, 'SCHEDULED')).every((x) => x.coach_id === coachB)).toBe(true);
    expect((await sessions(classId, 'CANCELLED'))[0].coach_id).toBe(coachA);
    expect((await patch(classId, { defaultCoachId: memberId })).body.error.code).toBe('COACH_INVALID');
  });

  it('a deactivated class loses its future sessions and the job no longer generates for it', async () => {
    expect((await patch(classId, { isActive: false })).status).toBe(200);
    expect(await sessions(classId, 'SCHEDULED')).toHaveLength(0);
    expect(await sessions(classId, 'CANCELLED')).toHaveLength(1);
    await runJob();
    expect(await sessions(classId, 'SCHEDULED')).toHaveLength(0);
    expect((await patch(classId, { isActive: true })).status).toBe(200);
    expect(await sessions(classId, 'SCHEDULED')).toHaveLength(9);
  });

  it('lists a class sessions (staff only) with range validation', async () => {
    const url = `/api/v1/admin/classes/${classId}/sessions`;
    expect((await ctx.api.get(url)).status).toBe(401);
    expect((await ctx.api.get(url).set(bearer(memberToken))).status).toBe(403);
    const def = await ctx.api.get(url).set(bearer(reception));
    expect(def.status).toBe(200);
    // 2 March .. 30 March inclusive: Mon x5 + Wed x4 (Apr 1 is outside) = 9 scheduled + the cancelled Friday.
    expect(def.body.data).toHaveLength(10);
    expect(def.body.data[0]).toMatchObject({
      classId,
      title: 'Boxing tối mới',
      date: '2026-03-02',
      status: 'SCHEDULED',
      startsAt: '2026-03-02T12:00:00.000Z',
      coach: { id: coachB, fullName: 'Coach B' },
      attendeeCount: 0,
    });
    const day = await ctx.api.get(`${url}?from=2026-03-13&to=2026-03-13`).set(bearer(admin));
    expect(day.body.data).toMatchObject([{ status: 'CANCELLED', attendeeCount: 1, date: '2026-03-13' }]);
    expect((await ctx.api.get(`${url}?from=2026-03-02&to=2026-06-02`).set(bearer(admin))).status).toBe(200);
    const big = await ctx.api.get(`${url}?from=2026-03-02&to=2026-06-03`).set(bearer(admin));
    expect([big.status, big.body.error.code]).toEqual([400, 'RANGE_TOO_LARGE']);
    const rev = await ctx.api.get(`${url}?from=2026-03-05&to=2026-03-01`).set(bearer(admin));
    expect([rev.status, rev.body.error.code]).toEqual([400, 'INVALID_RANGE']);
    expect((await ctx.api.get(`${url}?from=03-05-2026`).set(bearer(admin))).status).toBe(400);
    expect(
      (
        await ctx.api
          .get(`/api/v1/admin/classes/${'0'.repeat(8)}-0000-4000-8000-000000000000/sessions`)
          .set(bearer(admin))
      ).status,
    ).toBe(404);
  });
});
