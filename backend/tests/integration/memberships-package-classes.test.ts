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
      await ctx.api
        .post('/api/v1/admin/package-types')
        .set(bearer(admin))
        .send({
          code: 'WITH_CLASSES',
          name: 'Gói có lớp',
          durationDays: 30,
          totalSessions: 12,
          priceVnd: 2_000_000,
        })
    ).body.data.id;
    const mkClass = async (name: string, capacity: number | null) =>
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
            packageTypeId: pkg,
          })
      ).body.data.id as string;
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
      expect(e2).toMatchObject({ startDate: '2026-12-02', endDate: '2027-01-01' });
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
});
