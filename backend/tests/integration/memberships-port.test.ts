import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { DomainEvents, eventBus } from '../../src/common/events/event-bus';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { env } from '../../src/config/env';
import type { MembershipEvent } from '../../src/shared/events';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

const EVIDENCE = `${env.PUBLIC_BASE_URL}/files/evidence/abc.jpg`;

describe('MembershipPort and membership events (MEM-07)', () => {
  let ctx: TestContext;
  let staff: string;
  let book1: string;
  let book2: string;
  const seen: Record<string, MembershipEvent[]> = {};
  const eventsOf = (name: string, memberId: string) => (seen[name] ?? []).filter((e) => e.memberId === memberId);

  beforeAll(async () => {
    ctx = await bootTestApp();
    const mk = async (role: string) =>
      (await login(ctx.api, (await createStaff({ role, fullName: role, phone: nextPhone() } as never)).phone)).token;
    staff = await mk('RECEPTIONIST');
    const id = async (code: string) =>
      (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = $1`, [code]))[0].id;
    book1 = await id('BOOK_1');
    book2 = await id('BOOK_2');
    for (const name of ['ACTIVATED', 'SCHEDULED', 'EXPIRED', 'CANCELLED', 'COMPLETED'] as const)
      eventBus.on<MembershipEvent>(DomainEvents[`MEMBERSHIP_${name}`], (e) => {
        (seen[name] ??= []).push(e);
      });
  });
  afterEach(() => resetClock());

  const activate = (memberId: string, packageTypeId: string) =>
    ctx.api
      .post(`/api/v1/members/${memberId}/memberships`)
      .set(bearer(staff))
      .send({ packageTypeId, paymentEvidenceUrl: EVIDENCE });
  const insertMembership = async (memberId: string, total: number | null, used = 0) =>
    (
      await ownerQuery<{ id: string }>(
        `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, used_sessions)
         SELECT m.tenant_id, m.user_id, pt.id, '2026-10-01', '2026-12-31', $2, $3 FROM members m, package_types pt
          WHERE m.user_id = $1 AND pt.code = 'BOOK_1' RETURNING id`,
        [memberId, total, used],
      )
    )[0].id;

  it('findUsable honours dates and sessions left', async () => {
    const m = await registerMember(ctx.api);
    const find = (d: string) => ctx.tx(() => ctx.services.memberships.findUsable(m.userId, d));
    expect(await find('2026-10-15')).toBeNull();
    const id = await insertMembership(m.userId, 2, 1);
    expect(await find('2026-09-30')).toBeNull();
    expect(await find('2026-10-01')).toMatchObject({ id, sessionsRemaining: 1, totalSessions: 2, endDate: '2026-12-31' });
    expect(await find('2026-12-31')).not.toBeNull();
    expect(await find('2027-01-01')).toBeNull();
  });

  it('consumeSession counts down, completes on the last session and emits MEMBERSHIP_COMPLETED', async () => {
    const m = await registerMember(ctx.api);
    const id = await insertMembership(m.userId, 2);
    const consume = () => ctx.tx(() => ctx.services.memberships.consumeSession(id));
    const state = async () =>
      (await ownerQuery<{ status: string; used_sessions: number }>(`SELECT status, used_sessions FROM memberships WHERE id = $1`, [id]))[0];

    await consume();
    expect(await state()).toEqual({ status: 'ACTIVE', used_sessions: 1 });
    expect(eventsOf('COMPLETED', m.userId)).toHaveLength(0);
    await consume();
    expect(await state()).toEqual({ status: 'COMPLETED', used_sessions: 2 });
    expect(eventsOf('COMPLETED', m.userId)).toEqual([{ membershipId: id, memberId: m.userId, packageTypeId: expect.any(String) }]);
    await expect(consume()).rejects.toMatchObject({ status: 422, code: 'MEMBERSHIP_NOT_USABLE' });
  });

  it('keeps an exhausted package ACTIVE when its type does not expire on zero sessions', async () => {
    const m = await registerMember(ctx.api);
    const id = await insertMembership(m.userId, 1);
    await ownerQuery(`UPDATE package_types SET expire_on_zero_sessions = false WHERE code = 'BOOK_1'`);
    try {
      await ctx.tx(() => ctx.services.memberships.consumeSession(id));
    } finally {
      await ownerQuery(`UPDATE package_types SET expire_on_zero_sessions = true WHERE code = 'BOOK_1'`);
    }
    expect((await ownerQuery<{ status: string }>(`SELECT status FROM memberships WHERE id = $1`, [id]))[0].status).toBe('ACTIVE');
    expect(eventsOf('COMPLETED', m.userId)).toHaveLength(0);
    await expect(ctx.tx(() => ctx.services.memberships.consumeSession(id))).rejects.toMatchObject({ code: 'MEMBERSHIP_NOT_USABLE' });
  });

  it('emits ACTIVATED, SCHEDULED, EXPIRED and CANCELLED at the right moments', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    const a = await activate(m.userId, book1);
    expect(eventsOf('ACTIVATED', m.userId).map((e) => e.membershipId)).toEqual([a.body.data.membership.id]);
    const b = await activate(m.userId, book2);
    expect(eventsOf('SCHEDULED', m.userId)).toEqual([
      { membershipId: b.body.data.membership.id, memberId: m.userId, packageTypeId: book2 },
    ]);
    await ctx.api.post(`/api/v1/memberships/${b.body.data.membership.id}/cancel`).set(bearer(staff)).send({ reason: 'x' });
    expect(eventsOf('CANCELLED', m.userId).map((e) => e.membershipId)).toEqual([b.body.data.membership.id]);

    // The old ACTIVE package lapses -> a new activation expires it.
    setClock(fixedClock(new Date('2027-02-01T05:00:00Z')));
    const c = await activate(m.userId, book2);
    expect(c.body.data.mode).toBe('ACTIVATED');
    expect(eventsOf('EXPIRED', m.userId).map((e) => e.membershipId)).toEqual([a.body.data.membership.id]);
    expect(eventsOf('ACTIVATED', m.userId)).toHaveLength(2);
  });
});
