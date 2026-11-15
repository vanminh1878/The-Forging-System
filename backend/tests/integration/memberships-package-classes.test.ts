import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { env } from '../../src/config/env';
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

const EVIDENCE = `${env.PUBLIC_BASE_URL}/files/evidence/abc.jpg`;
const ZERO = '00000000-0000-4000-8000-000000000000';
// A Monday: the class below meets Mon/Wed/Fri 18:30 local time.
const MONDAY = new Date('2026-10-26T05:00:00Z');

describe('package -> class flow (PKG-03..05)', () => {
  let ctx: TestContext;
  let reception: string;
  let receptionId: string;
  let admin: string;
  let coachId: string;
  let book1: string;
  let pkg: string; // package with two classes
  let classA: string; // capacity 1
  let classB: string; // unlimited
  let q1: string;

  const rejects = async (p: Promise<unknown>) => {
    try {
      await p;
    } catch (e) {
      return [(e as { status: number }).status, (e as { code: string }).code];
    }
    return null;
  };
  const enrollments = (memberId: string) =>
    ownerQuery<{
      class_id: string;
      status: string;
      start_date: string;
      end_date: string | null;
      membership_id: string | null;
    }>(
      `SELECT class_id, status, start_date::text, end_date::text, membership_id FROM class_enrollments WHERE member_id = $1 ORDER BY created_at`,
      [memberId],
    );
  const activate = (memberId: string, body: object, token = reception) =>
    ctx.api
      .post(`/api/v1/members/${memberId}/memberships`)
      .set(bearer(token))
      .send({ paymentEvidenceUrl: EVIDENCE, ...body });
  const cancelMs = (id: string) =>
    ctx.api.post(`/api/v1/memberships/${id}/cancel`).set(bearer(admin)).send({ reason: 'Sai gói' });

  const mkClass = async (name: string, capacity: number | null, packageTypeId: string | null = pkg) =>
    (
      await ctx.api
        .post('/api/v1/admin/classes')
        .set(bearer(admin))
        .send({
          branchId: q1,
          name,
          sessionTypeCode: 'GROUP',
          weekdays: [1, 3, 5],
          startTime: '18:30',
          durationMinutes: 60,
          capacity,
          defaultCoachId: coachId,
          packageTypeId,
        })
    ).body.data.id as string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(MONDAY));
    const mk = async (role: string) => {
      const s = await createStaff({ role, fullName: role, phone: nextPhone() } as never);
      return { id: s.userId, token: (await login(ctx.api, s.phone)).token };
    };
    const r = await mk('RECEPTIONIST');
    reception = r.token;
    receptionId = r.id;
    admin = (await mk('ADMIN')).token;
    coachId = (await mk('COACH')).id;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    book1 = (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_1'`))[0].id;
    pkg = (
      await ctx.api.post('/api/v1/admin/package-types').set(bearer(admin)).send({
        code: 'WITH_CLASSES',
        name: 'Gói có lớp',
        durationDays: 30,
        totalSessions: 12,
        priceVnd: 2_000_000,
      })
    ).body.data.id;
    classA = await mkClass('Lớp A', 1);
    classB = await mkClass('Lớp B', null);
  });
  afterEach(() => setClock(fixedClock(MONDAY)));
  afterAll(() => resetClock());

  describe('ClassPort (PKG-03)', () => {
    it('hasActiveClasses / checkEnrollable validate the class against the package', async () => {
      const svc = ctx.services.classes;
      expect(await ctx.tx(() => svc.hasActiveClasses(pkg))).toBe(true);
      expect(await ctx.tx(() => svc.hasActiveClasses(book1))).toBe(false);
      const m = await registerMember(ctx.api);

      expect(await rejects(ctx.tx(() => svc.checkEnrollable(classA, book1)))).toEqual([
        422,
        'CLASS_NOT_IN_PACKAGE',
      ]);
      expect(await rejects(ctx.tx(() => svc.checkEnrollable(ZERO, pkg)))).toEqual([404, 'NOT_FOUND']);
      expect(await ctx.tx(() => svc.checkEnrollable(classA, pkg))).toBeUndefined();

      await ownerQuery(`UPDATE classes SET is_active = false WHERE id = $1`, [classB]);
      expect(await rejects(ctx.tx(() => svc.checkEnrollable(classB, pkg)))).toEqual([422, 'CLASS_INACTIVE']);
      await ownerQuery(`UPDATE classes SET is_active = true WHERE id = $1`, [classB]);

      // fill class A (capacity 1) with someone else
      const other = await registerMember(ctx.api);
      const ms = (await activate(other.userId, { packageTypeId: book1 })).body.data.membership.id;
      await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classA,
          memberId: other.userId,
          membershipId: ms,
          startDate: '2026-10-26',
          endDate: '2026-11-25',
          actorId: receptionId,
        }),
      );
      expect(await rejects(ctx.tx(() => svc.checkEnrollable(classA, pkg, m.userId)))).toEqual([
        409,
        'CLASS_FULL',
      ]);
      // the seat holder renewing the same class is not blocked by its own seat
      expect(await ctx.tx(() => svc.checkEnrollable(classA, pkg, other.userId))).toBeUndefined();
    });

    it('enrolls with the membership dates, extends a same-class enrolment and audits PACKAGE', async () => {
      const svc = ctx.services.classes;
      const m = await registerMember(ctx.api);
      const ms1 = (await activate(m.userId, { packageTypeId: book1 })).body.data.membership.id;
      const e1 = await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: m.userId,
          membershipId: ms1,
          startDate: '2026-10-26',
          endDate: '2026-12-01',
          actorId: receptionId,
        }),
      );
      expect(e1).toEqual({
        classId: classB,
        className: 'Lớp B',
        startDate: '2026-10-26',
        endDate: '2026-12-01',
      });

      const ms2 = (await activate(m.userId, { packageTypeId: book1 })).body.data.membership.id;
      const e2 = await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: m.userId,
          membershipId: ms2,
          startDate: '2026-12-02',
          endDate: '2027-01-01',
          actorId: receptionId,
        }),
      );
      expect(e2).toMatchObject({ startDate: '2026-10-26', endDate: '2027-01-01' });
      const rows = await enrollments(m.userId);
      expect(rows).toEqual([
        {
          class_id: classB,
          status: 'ACTIVE',
          start_date: '2026-10-26',
          end_date: '2027-01-01',
          membership_id: ms2,
        },
      ]);

      // open-ended on either side stays open-ended
      const ms3 = (await ownerQuery<{ id: string }>(`SELECT id FROM memberships WHERE id = $1`, [ms2]))[0].id;
      const e3 = await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: m.userId,
          membershipId: ms3,
          startDate: '2027-01-02',
          endDate: null,
          actorId: receptionId,
        }),
      );
      expect(e3.endDate).toBeNull();

      const audits = await ownerQuery<{ after_data: { op: string; extended: boolean }; reason: string }>(
        `SELECT after_data, reason FROM audit_logs WHERE action = 'ROSTER_UPDATED' AND entity_id = $1 AND reason = 'PACKAGE' ORDER BY created_at`,
        [classB],
      );
      expect(audits.length).toBeGreaterThanOrEqual(3);
      expect(audits[0].after_data).toMatchObject({ op: 'ENROLL', extended: false });
      expect(audits[1].after_data.extended).toBe(true);
    });

    it('cancelling a membership cancels its enrolments; an extended enrolment only loses the added days', async () => {
      const svc = ctx.services.classes;
      const m = await registerMember(ctx.api);
      const ms = (await activate(m.userId, { packageTypeId: book1 })).body.data.membership.id;
      await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: m.userId,
          membershipId: ms,
          startDate: '2026-10-26',
          endDate: '2026-12-01',
          actorId: receptionId,
        }),
      );
      expect((await cancelMs(ms)).status).toBe(200);
      expect((await enrollments(m.userId))[0]).toMatchObject({ status: 'CANCELLED' });
      expect(
        await ownerQuery(
          `SELECT 1 FROM audit_logs WHERE action = 'ROSTER_UPDATED' AND reason = 'MEMBERSHIP_CANCELLED' AND entity_id = $1`,
          [classB],
        ),
      ).not.toHaveLength(0);

      // renewal into the same class, then cancel the queued package: the current period stays
      const n = await registerMember(ctx.api);
      const cur = (await activate(n.userId, { packageTypeId: book1 })).body.data.membership; // 2026-10-26 .. 2027-01-17
      await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: n.userId,
          membershipId: cur.id,
          startDate: cur.startDate,
          endDate: cur.endDate,
          actorId: receptionId,
        }),
      );
      const next = (await activate(n.userId, { packageTypeId: book1 })).body.data.membership; // SCHEDULED
      expect(next.status).toBe('SCHEDULED');
      await ctx.tx(() =>
        svc.enrollForMembership({
          classId: classB,
          memberId: n.userId,
          membershipId: next.id,
          startDate: next.startDate,
          endDate: next.endDate,
          actorId: receptionId,
        }),
      );
      expect((await enrollments(n.userId))[0].end_date).toBe(next.endDate);
      expect((await cancelMs(next.id)).status).toBe(200);
      expect(await enrollments(n.userId)).toEqual([
        {
          class_id: classB,
          status: 'ACTIVE',
          start_date: cur.startDate,
          end_date: cur.endDate,
          membership_id: null,
        },
      ]);
    });
  });
  describe('renewal request with a class (PKG-04)', () => {
    const request = (token: string, body: object) =>
      ctx.api.post('/api/v1/me/renewal-requests').set(bearer(token)).send(body);

    it('enforces auth and validates classId', async () => {
      const m = await registerMember(ctx.api);
      expect((await ctx.api.post('/api/v1/me/renewal-requests').send({ packageTypeId: pkg })).status).toBe(
        401,
      );
      expect((await request(reception, { packageTypeId: pkg, classId: classB })).status).toBe(403);
      expect((await request(m.token, { packageTypeId: pkg, classId: 'nope' })).status).toBe(400);
    });

    it('requires a class when the package has classes, and refuses one when it has none', async () => {
      const m = await registerMember(ctx.api);
      const none = await request(m.token, { packageTypeId: pkg });
      expect([none.status, none.body.error.code, none.body.error.message]).toEqual([
        400,
        'CLASS_REQUIRED',
        'Vui lòng chọn lớp.',
      ]);
      const extra = await request(m.token, { packageTypeId: book1, classId: classB });
      expect([extra.status, extra.body.error.code]).toEqual([422, 'CLASS_NOT_IN_PACKAGE']);
      const other = await mkClass('Lớp gói khác', null, book1);
      const wrong = await request(m.token, { packageTypeId: pkg, classId: other });
      expect([wrong.status, wrong.body.error.code, wrong.body.error.message]).toEqual([
        422,
        'CLASS_NOT_IN_PACKAGE',
        'Lớp không thuộc gói đã chọn.',
      ]);
      // the book1 package now has a class: it becomes mandatory there too
      expect((await request(m.token, { packageTypeId: book1 })).body.error.code).toBe('CLASS_REQUIRED');
      await ownerQuery(`UPDATE classes SET is_active = false WHERE id = $1`, [other]);
      expect((await request(m.token, { packageTypeId: book1, classId: other })).body.error.code).toBe(
        'CLASS_NOT_IN_PACKAGE',
      );
      expect(
        await ownerQuery(`SELECT 1 FROM renewal_requests WHERE member_id = $1`, [m.userId]),
      ).toHaveLength(0);
    });

    it('answers CLASS_INACTIVE and CLASS_FULL without creating a request', async () => {
      const m = await registerMember(ctx.api);
      const off = await mkClass('Lớp tắt', null);
      await ownerQuery(`UPDATE classes SET is_active = false WHERE id = $1`, [off]);
      const inactive = await request(m.token, { packageTypeId: pkg, classId: off });
      expect([inactive.status, inactive.body.error.code]).toEqual([422, 'CLASS_INACTIVE']);

      const tiny = await mkClass('Lớp một chỗ', 1);
      const holder = await registerMember(ctx.api);
      const ms = (await activate(holder.userId, { packageTypeId: book1 })).body.data.membership.id;
      await ctx.tx(() =>
        ctx.services.classes.enrollForMembership({
          classId: tiny,
          memberId: holder.userId,
          membershipId: ms,
          startDate: '2026-10-26',
          endDate: null,
          actorId: receptionId,
        }),
      );
      const full = await request(m.token, { packageTypeId: pkg, classId: tiny });
      expect([full.status, full.body.error.code]).toEqual([409, 'CLASS_FULL']);
      expect(
        await ownerQuery(`SELECT 1 FROM renewal_requests WHERE member_id = $1`, [m.userId]),
      ).toHaveLength(0);
    });

    it('stores the class on the request and shows it to the learner and reception; no seat is held yet', async () => {
      const m = await registerMember(ctx.api, { fullName: 'Học Viên Lớp' });
      const res = await request(m.token, { packageTypeId: pkg, classId: classB, note: ' chọn lớp B ' });
      expect(res.status).toBe(201);
      expect(res.body.data).toMatchObject({
        status: 'PENDING',
        note: 'chọn lớp B',
        desiredPackage: { id: pkg },
        class: {
          id: classB,
          name: 'Lớp B',
          branchName: expect.any(String),
          weekdays: [1, 3, 5],
          startTime: '18:30',
        },
      });
      const mine = await ctx.api.get('/api/v1/me/renewal-requests').set(bearer(m.token));
      expect(mine.body.data[0].class).toMatchObject({ id: classB, name: 'Lớp B' });
      const inbox = await ctx.api
        .get('/api/v1/renewal-requests?status=PENDING&q=Học Viên Lớp')
        .set(bearer(reception));
      expect(inbox.body.data[0].class).toMatchObject({ id: classB, startTime: '18:30' });
      expect(await enrollments(m.userId)).toHaveLength(0);
      const note = await ownerQuery<{ body: string }>(
        `SELECT body FROM staff_notifications WHERE event_type = 'RENEWAL_REQUEST' ORDER BY created_at DESC LIMIT 1`,
      );
      expect(note[0].body).toContain('Lớp B');
      const audit = await ownerQuery<{ after_data: { classId: string } }>(
        `SELECT after_data FROM audit_logs WHERE action = 'RENEWAL_REQUESTED' AND entity_id = $1`,
        [res.body.data.id],
      );
      expect(audit[0].after_data.classId).toBe(classB);
    });

    it('keeps class null for a package without classes', async () => {
      await ownerQuery(`UPDATE package_types SET is_active = true WHERE code = 'BOOK_2'`);
      const book2 = (
        await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_2'`)
      )[0].id;
      const m = await registerMember(ctx.api);
      const res = await request(m.token, { packageTypeId: book2 });
      expect(res.status).toBe(201);
      expect(res.body.data.class).toBeNull();
    });
  });
  describe('activate / approve with a class (PKG-05)', () => {
    const request = (token: string, body: object) =>
      ctx.api.post('/api/v1/me/renewal-requests').set(bearer(token)).send(body);
    const approve = (id: string, body: object = {}, token = reception) =>
      ctx.api
        .post(`/api/v1/renewal-requests/${id}/approve`)
        .set(bearer(token))
        .send({ paymentEvidenceUrl: EVIDENCE, ...body });
    const membershipCount = async (memberId: string) =>
      (await ownerQuery(`SELECT 1 FROM memberships WHERE member_id = $1`, [memberId])).length;
    const requestStatus = async (id: string) =>
      (await ownerQuery<{ status: string }>(`SELECT status FROM renewal_requests WHERE id = $1`, [id]))[0]
        .status;

    it('manual activation enrols the learner for the membership dates and the class shows on the schedule', async () => {
      const m = await registerMember(ctx.api);
      const res = await activate(m.userId, { packageTypeId: pkg, classId: classB });
      expect(res.status).toBe(201);
      expect(res.body.data.mode).toBe('ACTIVATED');
      expect(res.body.data.membership).toMatchObject({ startDate: '2026-10-26', endDate: '2026-11-24' });
      expect(res.body.data.enrollment).toEqual({
        classId: classB,
        className: 'Lớp B',
        startDate: '2026-10-26',
        endDate: '2026-11-24',
      });
      expect(await enrollments(m.userId)).toEqual([
        {
          class_id: classB,
          status: 'ACTIVE',
          start_date: '2026-10-26',
          end_date: '2026-11-24',
          membership_id: res.body.data.membership.id,
        },
      ]);
      const schedule = await ctx.api
        .get('/api/v1/me/schedule?view=month&date=2026-10-26')
        .set(bearer(m.token));
      const mine = schedule.body.data.filter((i: { title: string }) => i.title === 'Lớp B');
      expect(mine.length).toBeGreaterThanOrEqual(3);
      expect(mine[0]).toMatchObject({ sessionType: 'GROUP', status: 'UPCOMING' });
      const audit = await ownerQuery(
        `SELECT 1 FROM audit_logs WHERE action = 'ROSTER_UPDATED' AND reason = 'PACKAGE' AND actor_id = $1`,
        [receptionId],
      );
      expect(audit.length).toBeGreaterThan(0);
    });

    it('manual activation validates the class and creates nothing on error', async () => {
      const m = await registerMember(ctx.api);
      const other = await mkClass('Lớp khác gói', null, null);
      const book2 = (
        await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_2'`)
      )[0].id;
      expect((await activate(m.userId, { packageTypeId: pkg, classId: 'nope' })).status).toBe(400);
      const none = await activate(m.userId, { packageTypeId: pkg });
      expect([none.status, none.body.error.code]).toEqual([400, 'CLASS_REQUIRED']);
      const wrong = await activate(m.userId, { packageTypeId: pkg, classId: other });
      expect([wrong.status, wrong.body.error.code]).toEqual([422, 'CLASS_NOT_IN_PACKAGE']);
      const extra = await activate(m.userId, { packageTypeId: book2, classId: classB });
      expect([extra.status, extra.body.error.code]).toEqual([422, 'CLASS_NOT_IN_PACKAGE']);
      expect((await activate(m.userId, { packageTypeId: pkg, classId: ZERO })).status).toBe(404);
      expect(await membershipCount(m.userId)).toBe(0);
      // a package without classes still activates without one
      const plain = await activate(m.userId, { packageTypeId: book2 });
      expect(plain.status).toBe(201);
      expect(plain.body.data.enrollment).toBeNull();
    });

    it('approve uses the request class: enrolment from today for an ACTIVE package', async () => {
      const m = await registerMember(ctx.api);
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const res = await approve(rr);
      expect(res.status).toBe(200);
      expect(res.body.data.enrollment).toMatchObject({
        classId: classB,
        startDate: '2026-10-26',
        endDate: '2026-11-24',
      });
      expect(await requestStatus(rr)).toBe('COMPLETED');
      expect((await enrollments(m.userId))[0]).toMatchObject({
        class_id: classB,
        membership_id: res.body.data.membership.id,
      });
    });

    it('approve for a SCHEDULED package starts the enrolment on the follow-on date', async () => {
      const m = await registerMember(ctx.api);
      expect((await activate(m.userId, { packageTypeId: book1 })).status).toBe(201); // 2026-10-26 .. 2027-01-17
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const res = await approve(rr);
      expect(res.body.data.mode).toBe('SCHEDULED');
      expect(res.body.data.membership.startDate).toBe('2027-01-18');
      expect(res.body.data.enrollment).toEqual({
        classId: classB,
        className: 'Lớp B',
        startDate: '2027-01-18',
        endDate: '2027-02-16',
      });
      const rows = await enrollments(m.userId);
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ start_date: '2027-01-18', end_date: '2027-02-16' });
      const week = await ctx.api.get('/api/v1/me/schedule?date=2026-10-26').set(bearer(m.token));
      expect(week.body.data.filter((i: { title: string }) => i.title === 'Lớp B')).toHaveLength(0);
    });

    it('renewing the same class extends the enrolment instead of adding a row', async () => {
      const m = await registerMember(ctx.api);
      const first = await activate(m.userId, { packageTypeId: pkg, classId: classB });
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const res = await approve(rr);
      expect(res.body.data.mode).toBe('SCHEDULED');
      expect(res.body.data.enrollment).toMatchObject({ startDate: '2026-10-26', endDate: '2026-12-24' });
      expect(await enrollments(m.userId)).toEqual([
        {
          class_id: classB,
          status: 'ACTIVE',
          start_date: '2026-10-26',
          end_date: '2026-12-24',
          membership_id: res.body.data.membership.id,
        },
      ]);
      expect(first.body.data.membership.id).not.toBe(res.body.data.membership.id);
    });

    it('a classId in the approve body overrides the class of the request', async () => {
      const m = await registerMember(ctx.api);
      const classC = await mkClass('Lớp C', 5);
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const res = await approve(rr, { classId: classC });
      expect(res.status).toBe(200);
      expect((await enrollments(m.userId)).map((e) => e.class_id)).toEqual([classC]);
    });

    it('a full class at approve time answers 409 and leaves the request PENDING with no membership', async () => {
      const m = await registerMember(ctx.api);
      const tiny = await mkClass('Lớp một chỗ 2', 1);
      const rr = (await request(m.token, { packageTypeId: pkg, classId: tiny })).body.data.id;
      const rival = await registerMember(ctx.api);
      expect((await activate(rival.userId, { packageTypeId: pkg, classId: tiny })).status).toBe(201);
      const res = await approve(rr);
      expect([res.status, res.body.error.code]).toEqual([409, 'CLASS_FULL']);
      expect(await requestStatus(rr)).toBe('PENDING');
      expect(await membershipCount(m.userId)).toBe(0);
      expect(await enrollments(m.userId)).toHaveLength(0);
      // after the rival leaves, the same request can be approved
      await ctx.api
        .delete(`/api/v1/admin/classes/${tiny}/enrollments/${rival.userId}`)
        .set(bearer(reception));
      expect((await approve(rr)).status).toBe(200);
    });

    it('switching the package at approve needs a class of the new package', async () => {
      const m = await registerMember(ctx.api);
      const book2 = (
        await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_2'`)
      )[0].id;
      const rr = (await request(m.token, { packageTypeId: book2 })).body.data.id;
      const none = await approve(rr, { packageTypeId: pkg });
      expect([none.status, none.body.error.code]).toEqual([400, 'CLASS_REQUIRED']);
      const other = await mkClass('Lớp khác gói 2', null, null);
      const wrong = await approve(rr, { packageTypeId: pkg, classId: other });
      expect([wrong.status, wrong.body.error.code]).toEqual([422, 'CLASS_NOT_IN_PACKAGE']);
      expect(await requestStatus(rr)).toBe('PENDING');
      expect(await membershipCount(m.userId)).toBe(0);
      const ok = await approve(rr, { packageTypeId: pkg, classId: classB });
      expect(ok.status).toBe(200);
      expect(ok.body.data.enrollment.classId).toBe(classB);
    });

    it('switching to a package without classes drops the request class', async () => {
      const m = await registerMember(ctx.api);
      const book2 = (
        await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_2'`)
      )[0].id;
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const res = await approve(rr, { packageTypeId: book2 });
      expect(res.status).toBe(200);
      expect(res.body.data.enrollment).toBeNull();
      expect(await enrollments(m.userId)).toHaveLength(0);
    });

    it('cancelling the membership cancels the enrolment made by the approval', async () => {
      const m = await registerMember(ctx.api);
      const rr = (await request(m.token, { packageTypeId: pkg, classId: classB })).body.data.id;
      const ms = (await approve(rr)).body.data.membership.id;
      expect((await cancelMs(ms)).status).toBe(200);
      expect((await enrollments(m.userId))[0]).toMatchObject({ status: 'CANCELLED' });
      const schedule = await ctx.api
        .get('/api/v1/me/schedule?view=month&date=2026-10-26')
        .set(bearer(m.token));
      expect(schedule.body.data.filter((i: { title: string }) => i.title === 'Lớp B')).toHaveLength(0);
    });
  });

  describe('expired enrolments and gaps', () => {
    const LATER = new Date('2027-01-04T05:00:00Z'); // a Monday after the 30-day packages above ran out

    it('an expired package no longer holds a seat', async () => {
      const classC = await mkClass('Lớp C', 1);
      const x = await registerMember(ctx.api);
      const y = await registerMember(ctx.api);
      expect((await activate(x.userId, { packageTypeId: pkg, classId: classC })).status).toBe(201);
      const full = await activate(y.userId, { packageTypeId: pkg, classId: classC });
      expect([full.status, full.body.error.code]).toEqual([409, 'CLASS_FULL']);

      setClock(fixedClock(LATER));
      const list = await ctx.api.get(`/api/v1/package-types/${pkg}/classes`).set(bearer(y.token));
      expect(list.body.data.find((c: { id: string }) => c.id === classC).seatsLeft).toBe(1);
      expect((await activate(y.userId, { packageTypeId: pkg, classId: classC })).status).toBe(201);
    });

    it('coming back to the same class after a gap closes the old stint instead of stretching it', async () => {
      const z = await registerMember(ctx.api);
      const first = (await activate(z.userId, { packageTypeId: pkg, classId: classB })).body.data.membership.id;
      setClock(fixedClock(LATER));
      const res = await activate(z.userId, { packageTypeId: pkg, classId: classB });
      expect(res.status).toBe(201);
      expect(res.body.data.enrollment).toMatchObject({ startDate: '2027-01-04', endDate: '2027-02-02' });
      expect(await enrollments(z.userId)).toEqual([
        { class_id: classB, status: 'ENDED', start_date: '2026-10-26', end_date: '2026-11-24', membership_id: first },
        {
          class_id: classB,
          status: 'ACTIVE',
          start_date: '2027-01-04',
          end_date: '2027-02-02',
          membership_id: res.body.data.membership.id,
        },
      ]);
    });

    it('GET /me/membership shows the class of the pending request', async () => {
      const m = await registerMember(ctx.api);
      await ctx.api.post('/api/v1/me/renewal-requests').set(bearer(m.token)).send({ packageTypeId: pkg, classId: classB });
      const me = await ctx.api.get('/api/v1/me/membership').set(bearer(m.token));
      expect(me.body.data.pendingRenewal.class).toMatchObject({ id: classB, name: 'Lớp B', weekdays: [1, 3, 5], startTime: '18:30' });
    });
  });
});
