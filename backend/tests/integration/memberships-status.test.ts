import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import {
  bearer,
  bootTestApp,
  createStaff,
  login,
  nextPhone,
  ownerQuery,
  registerMember,
} from '../helpers/test-app';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import type { TestContext } from '../helpers/test-app';

describe('GET /me/membership (MEM-02)', () => {
  let ctx: TestContext;
  let staffToken: string;
  let coachToken: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    staffToken = (
      await login(
        ctx.api,
        (await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() })).phone,
      )
    ).token;
    coachToken = (
      await login(ctx.api, (await createStaff({ role: 'COACH', fullName: 'HLV', phone: nextPhone() })).phone)
    ).token;
  });
  afterEach(() => resetClock());

  const overview = async (token: string) =>
    (await ctx.api.get('/api/v1/me/membership').set(bearer(token))).body.data;
  const addMembership = async (
    memberId: string,
    o: {
      code?: string;
      status?: string;
      start: string;
      end: string | null;
      total?: number | null;
      used?: number;
    },
  ) =>
    ownerQuery(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, used_sessions, status)
       SELECT m.tenant_id, m.user_id, pt.id, $3, $4, $5, $6, $7 FROM members m, package_types pt
        WHERE m.user_id = $1 AND pt.code = $2`,
      [
        memberId,
        o.code ?? 'BOOK_1',
        o.start,
        o.end,
        o.total === undefined ? 36 : o.total,
        o.used ?? 0,
        o.status ?? 'ACTIVE',
      ],
    );

  it('enforces roles', async () => {
    const m = await registerMember(ctx.api);
    expect((await ctx.api.get('/api/v1/me/membership')).status).toBe(401);
    expect((await ctx.api.get('/api/v1/me/membership').set(bearer(staffToken))).status).toBe(403);
    expect((await ctx.api.get(`/api/v1/members/${m.userId}/membership`).set(bearer(m.token))).status).toBe(
      403,
    );
    expect((await ctx.api.get(`/api/v1/members/${m.userId}/membership`).set(bearer(coachToken))).status).toBe(
      403,
    );
  });

  it('validates and 404s the staff lookup', async () => {
    expect((await ctx.api.get('/api/v1/members/nope/membership').set(bearer(staffToken))).status).toBe(400);
    expect(
      (
        await ctx.api
          .get('/api/v1/members/00000000-0000-4000-8000-000000000000/membership')
          .set(bearer(staffToken))
      ).status,
    ).toBe(404);
  });

  it('NO_PACKAGE for a member without any package', async () => {
    const m = await registerMember(ctx.api);
    expect(await overview(m.token)).toMatchObject({
      memberStatus: 'ACTIVE',
      current: null,
      scheduled: null,
      pendingRenewal: null,
      renewNotice: 'NO_PACKAGE',
      canRenewEarly: false,
    });
  });

  it('OK with usage, then ENDING_SOON exactly at the day threshold', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z'))); // 12:00 in Asia/Ho_Chi_Minh
    const m = await registerMember(ctx.api);
    await addMembership(m.userId, { start: '2026-09-01', end: '2026-11-01', total: 36, used: 10 });
    const a = await overview(m.token);
    expect(a.current).toMatchObject({
      status: 'ACTIVE',
      sessionsRemaining: 26,
      daysRemaining: 8,
      endingSoon: false,
      packageType: { code: 'BOOK_1' },
    });
    expect(a).toMatchObject({ renewNotice: 'OK', canRenewEarly: true });

    setClock(fixedClock(new Date('2026-10-25T05:00:00Z'))); // 7 days left (remind_days = 7)
    const b = await overview(m.token);
    expect(b.current).toMatchObject({ daysRemaining: 7, endingSoon: true });
    expect(b.renewNotice).toBe('ENDING_SOON');
    // Staff see the same payload.
    const s = await ctx.api.get(`/api/v1/members/${m.userId}/membership`).set(bearer(staffToken));
    expect(s.body.data.current.daysRemaining).toBe(7);
  });

  it('uses the tenant timezone for "today" (UTC evening is already tomorrow in VN)', async () => {
    setClock(fixedClock(new Date('2026-10-24T18:00:00Z'))); // 2026-10-25 01:00 local
    const m = await registerMember(ctx.api);
    await addMembership(m.userId, { start: '2026-09-01', end: '2026-10-25', total: null });
    expect((await overview(m.token)).current).toMatchObject({ daysRemaining: 0, sessionsRemaining: null });
  });

  it('ENDING_SOON at the session threshold; ENDED when sessions run out', async () => {
    const m = await registerMember(ctx.api);
    await addMembership(m.userId, { start: '2026-09-01', end: '2027-12-31', total: 36, used: 34 });
    expect((await overview(m.token)).renewNotice).toBe('ENDING_SOON');
    await ownerQuery(`UPDATE memberships SET used_sessions = 36 WHERE member_id = $1`, [m.userId]);
    expect(await overview(m.token)).toMatchObject({ renewNotice: 'ENDED', canRenewEarly: false });
  });

  it('ENDED after a completed package, with the queued package and pending request shown', async () => {
    const m = await registerMember(ctx.api);
    await addMembership(m.userId, { status: 'EXPIRED', start: '2026-01-01', end: '2026-03-01' });
    expect(await overview(m.token)).toMatchObject({ renewNotice: 'ENDED', current: null });

    await addMembership(m.userId, { start: '2026-10-01', end: '2027-12-31', total: 36, used: 35 });
    await addMembership(m.userId, {
      code: 'BOOK_2',
      status: 'SCHEDULED',
      start: '2028-01-01',
      end: '2028-03-25',
    });
    await ownerQuery(
      `INSERT INTO renewal_requests (tenant_id, member_id, desired_package_type_id, note)
       SELECT m.tenant_id, m.user_id, pt.id, 'gia hạn' FROM members m, package_types pt WHERE m.user_id = $1 AND pt.code = 'BOOK_3'`,
      [m.userId],
    );
    const d = await overview(m.token);
    expect(d.scheduled).toMatchObject({ status: 'SCHEDULED', packageType: { code: 'BOOK_2' } });
    expect(d.pendingRenewal).toMatchObject({
      packageName: expect.stringContaining('BOOK III'),
      priceVnd: 10_800_000,
      note: 'gia hạn',
    });
    expect(d).toMatchObject({ renewNotice: 'OK', canRenewEarly: false });
  });

  it('reports the member account status', async () => {
    const m = await registerMember(ctx.api);
    await ownerQuery(`UPDATE members SET status = 'FROZEN', status_since = now() WHERE user_id = $1`, [
      m.userId,
    ]);
    expect((await overview(m.token)).memberStatus).toBe('FROZEN');
  });
});
