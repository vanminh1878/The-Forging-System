import { beforeAll, describe, expect, it } from 'vitest';
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

describe('classes: CRUD and enrollment', () => {
  let ctx: TestContext;
  let admin: string;
  let adminId: string;
  let reception: string;
  let coachToken: string;
  let coachId: string;
  let memberToken: string;
  let memberId: string;
  let q1: string;
  let inactiveBranch: string;
  let classId: string;

  const body = (over: Record<string, unknown> = {}) => ({
    branchId: q1,
    name: 'Boxing sáng',
    sessionTypeCode: 'GROUP',
    weekdays: [1, 3, 5],
    startTime: '06:30',
    durationMinutes: 60,
    capacity: 2,
    ...over,
  });
  const post = (b: unknown, t = admin) =>
    ctx.api
      .post('/api/v1/admin/classes')
      .set(bearer(t))
      .send(b as object);
  const enroll = (cid: string, b: object, t = reception) =>
    ctx.api.post(`/api/v1/admin/classes/${cid}/enrollments`).set(bearer(t)).send(b);

  beforeAll(async () => {
    ctx = await bootTestApp();
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminId = a.userId;
    admin = (await login(ctx.api, a.phone)).token;
    const r = await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() });
    reception = (await login(ctx.api, r.phone)).token;
    const c = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    coachId = c.userId;
    coachToken = (await login(ctx.api, c.phone)).token;
    const m = await registerMember(ctx.api);
    memberToken = m.token;
    memberId = m.userId;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    inactiveBranch = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO branches (tenant_id, code, name, is_active) SELECT id, 'OLDC', 'Old', false FROM tenants WHERE code = 'hvp' RETURNING id`,
      )
    )[0].id;
  });

  it('creates a class (admin only) and audits it', async () => {
    expect((await post(body(), reception)).status).toBe(403);
    expect((await ctx.api.post('/api/v1/admin/classes').send(body())).status).toBe(401);
    const res = await post(body({ defaultCoachId: coachId }));
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      branchId: q1,
      name: 'Boxing sáng',
      weekdays: [1, 3, 5],
      startTime: '06:30',
      capacity: 2,
      isActive: true,
      defaultCoachId: coachId,
    });
    classId = res.body.data.id;
    const audit = await ownerQuery(
      `SELECT 1 FROM audit_logs WHERE action = 'CLASS_CREATED' AND entity_id = $1 AND actor_id = $2`,
      [classId, adminId],
    );
    expect(audit).toHaveLength(1);
  });

  it('validates the create body and references', async () => {
    expect((await post(body({ weekdays: [] }))).status).toBe(400);
    expect((await post(body({ weekdays: [1, 1] }))).status).toBe(400);
    expect((await post(body({ weekdays: [8] }))).status).toBe(400);
    expect((await post(body({ startTime: '6:30' }))).status).toBe(400);
    expect((await post(body({ durationMinutes: 0 }))).status).toBe(400);
    const b = await post(body({ branchId: inactiveBranch }));
    expect([b.status, b.body.error.code]).toEqual([422, 'BRANCH_INACTIVE']);
    const s = await post(body({ sessionTypeCode: 'NOPE' }));
    expect([s.status, s.body.error.code]).toEqual([400, 'SESSION_TYPE_NOT_FOUND']);
    const c = await post(body({ defaultCoachId: memberId }));
    expect([c.status, c.body.error.code]).toEqual([400, 'COACH_INVALID']);
  });

  it('patches a class and audits it', async () => {
    const res = await ctx.api
      .patch(`/api/v1/admin/classes/${classId}`)
      .set(bearer(admin))
      .send({ name: 'Boxing tối', startTime: '18:00', isActive: true });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ name: 'Boxing tối', startTime: '18:00', weekdays: [1, 3, 5] });
    expect((await ctx.api.patch(`/api/v1/admin/classes/${classId}`).set(bearer(admin)).send({})).status).toBe(
      400,
    );
    expect(
      (await ctx.api.patch(`/api/v1/admin/classes/${classId}`).set(bearer(reception)).send({ name: 'x' }))
        .status,
    ).toBe(403);
    const bad = await ctx.api
      .patch(`/api/v1/admin/classes/${classId}`)
      .set(bearer(admin))
      .send({ branchId: inactiveBranch });
    expect(bad.body.error.code).toBe('BRANCH_INACTIVE');
    expect(
      (
        await ctx.api
          .patch(`/api/v1/admin/classes/${'0'.repeat(8)}-0000-4000-8000-000000000000`)
          .set(bearer(admin))
          .send({ name: 'x' })
      ).status,
    ).toBe(404);
    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'CLASS_UPDATED' AND entity_id = $1`, [
        classId,
      ]),
    ).toHaveLength(1);
  });

  it('enrolls members, enforces duplicates and capacity, then ends enrollments', async () => {
    expect((await enroll(classId, { memberId }, memberToken)).status).toBe(403);
    const ok1 = await enroll(classId, { memberId });
    expect(ok1.status).toBe(201);
    const dup = await enroll(classId, { memberId });
    expect([dup.status, dup.body.error.code]).toEqual([409, 'ALREADY_ENROLLED']);
    expect((await enroll(classId, { memberId: 'bad' })).status).toBe(400);

    const m2 = await registerMember(ctx.api);
    expect((await enroll(classId, { memberId: m2.userId })).status).toBe(201);
    const m3 = await registerMember(ctx.api);
    const full = await enroll(classId, { memberId: m3.userId });
    expect([full.status, full.body.error.code]).toEqual([409, 'CLASS_FULL']);

    const detail = await ctx.api.get(`/api/v1/admin/classes/${classId}`).set(bearer(coachToken));
    expect(detail.status).toBe(200);
    expect(detail.body.data.enrolledCount).toBe(2);
    expect(detail.body.data.roster[0]).toMatchObject({
      memberId: expect.any(String),
      memberCode: expect.any(String),
      fullName: expect.any(String),
    });
    expect((await ctx.api.get(`/api/v1/admin/classes/${classId}`).set(bearer(memberToken))).status).toBe(403);

    const del = await ctx.api
      .delete(`/api/v1/admin/classes/${classId}/enrollments/${memberId}`)
      .set(bearer(reception))
      .send({ reason: 'Nghỉ tập' });
    expect(del.status).toBe(200);
    const row = await ownerQuery<{ status: string; end_date: string | null }>(
      `SELECT status, end_date FROM class_enrollments WHERE class_id = $1 AND member_id = $2`,
      [classId, memberId],
    );
    expect(row[0].status).toBe('ENDED');
    expect(row[0].end_date).not.toBeNull();
    expect(
      (
        await ctx.api
          .delete(`/api/v1/admin/classes/${classId}/enrollments/${memberId}`)
          .set(bearer(reception))
      ).status,
    ).toBe(404);
    // freed seat can be taken again (re-enrolling the ended member is allowed too)
    expect((await enroll(classId, { memberId })).status).toBe(201);
    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'ROSTER_UPDATED' AND entity_id = $1`, [
        classId,
      ]),
    ).toHaveLength(4);
  });

  it('rejects inactive and merged members', async () => {
    const other = (await post(body({ capacity: null, name: 'Open' }))).body.data.id as string;
    const m = await registerMember(ctx.api);
    await ownerQuery(`UPDATE members SET status = 'INACTIVE', status_since = now() WHERE user_id = $1`, [
      m.userId,
    ]);
    const r = await enroll(other, { memberId: m.userId });
    expect([r.status, r.body.error.code]).toEqual([422, 'MEMBER_INACTIVE']);
    const m2 = await registerMember(ctx.api);
    await ownerQuery(`UPDATE members SET duplicate_of_member_id = $2 WHERE user_id = $1`, [
      m2.userId,
      memberId,
    ]);
    expect((await enroll(other, { memberId: m2.userId })).body.error.code).toBe('MEMBER_INACTIVE');
    expect((await enroll(other, { memberId: '0'.repeat(8) + '-0000-4000-8000-000000000000' })).status).toBe(
      404,
    );
  });

  it('lists classes with filters and pagination', async () => {
    const res = await ctx.api
      .get('/api/v1/admin/classes?isActive=true&sessionTypeCode=GROUP&limit=1')
      .set(bearer(coachToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toHaveProperty('enrolledCount');
    expect(res.body.meta.total).toBeGreaterThanOrEqual(2);
    const none = await ctx.api.get(`/api/v1/admin/classes?branchId=${inactiveBranch}`).set(bearer(admin));
    expect(none.body.data).toEqual([]);
    expect((await ctx.api.get('/api/v1/admin/classes?isActive=maybe').set(bearer(admin))).status).toBe(400);
  });
});
