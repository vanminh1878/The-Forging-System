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

describe('renewal requests (MEM-03)', () => {
  let ctx: TestContext;
  let staffToken: string;
  let coachToken: string;
  let book2: string;

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
    book2 = (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_2'`))[0].id;
  });

  const post = (token: string, body: unknown) =>
    ctx.api
      .post('/api/v1/me/renewal-requests')
      .set(bearer(token))
      .send(body as object);

  it('enforces roles and validation', async () => {
    const m = await registerMember(ctx.api);
    expect((await ctx.api.post('/api/v1/me/renewal-requests').send({ packageTypeId: book2 })).status).toBe(
      401,
    );
    expect((await post(staffToken, { packageTypeId: book2 })).status).toBe(403);
    expect((await post(m.token, { packageTypeId: 'x' })).status).toBe(400);
    expect((await post(m.token, { packageTypeId: book2, note: 'a'.repeat(501) })).status).toBe(400);
    expect((await ctx.api.get('/api/v1/renewal-requests').set(bearer(m.token))).status).toBe(403);
    expect((await ctx.api.get('/api/v1/renewal-requests').set(bearer(coachToken))).status).toBe(403);
    expect((await ctx.api.get('/api/v1/me/renewal-requests').set(bearer(staffToken))).status).toBe(403);
    expect((await ctx.api.get('/api/v1/renewal-requests?status=NOPE').set(bearer(staffToken))).status).toBe(
      400,
    );
  });

  it('creates a request, links the current membership, notifies, audits, then blocks a second one', async () => {
    const m = await registerMember(ctx.api, { fullName: 'Nguyễn Gia Hạn' });
    const ms = await ownerQuery<{ id: string }>(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions)
       SELECT m.tenant_id, m.user_id, pt.id, '2026-09-01', '2026-11-30', 36 FROM members m, package_types pt
        WHERE m.user_id = $1 AND pt.code = 'BOOK_1' RETURNING id`,
      [m.userId],
    );
    const res = await post(m.token, { packageTypeId: book2, note: '  tuần sau tôi qua  ' });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      status: 'PENDING',
      note: 'tuần sau tôi qua',
      member: { id: m.userId, fullName: 'Nguyễn Gia Hạn' },
      desiredPackage: { id: book2, priceVnd: 9_800_000 },
      currentMembership: { id: ms[0].id, endDate: '2026-11-30' },
    });

    const row = (
      await ownerQuery<{ current_membership_id: string }>(
        `SELECT current_membership_id FROM renewal_requests WHERE id = $1`,
        [res.body.data.id],
      )
    )[0];
    expect(row.current_membership_id).toBe(ms[0].id);
    expect(
      await ownerQuery(`SELECT 1 FROM notifications WHERE user_id = $1 AND event_type = 'RENEWAL_SENT'`, [
        m.userId,
      ]),
    ).toHaveLength(1);
    expect(
      (
        await ownerQuery(
          `SELECT 1 FROM staff_notifications WHERE event_type = 'RENEWAL_REQUEST' AND to_role = 'RECEPTIONIST'`,
        )
      ).length,
    ).toBeGreaterThanOrEqual(1);
    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'RENEWAL_REQUESTED' AND entity_id = $1`, [
        res.body.data.id,
      ]),
    ).toHaveLength(1);

    const again = await post(m.token, { packageTypeId: book2 });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('RENEWAL_PENDING_EXISTS');
    expect(
      await ownerQuery(`SELECT 1 FROM notifications WHERE user_id = $1 AND event_type = 'RENEWAL_SENT'`, [
        m.userId,
      ]),
    ).toHaveLength(1);

    // /me/membership now shows the pending request.
    const ov = await ctx.api.get('/api/v1/me/membership').set(bearer(m.token));
    expect(ov.body.data.pendingRenewal.id).toBe(res.body.data.id);
  });

  it('maps concurrent submissions to a single request and a 409', async () => {
    const m = await registerMember(ctx.api);
    const results = await Promise.all([
      post(m.token, { packageTypeId: book2 }),
      post(m.token, { packageTypeId: book2 }),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
  });

  it('rejects inactive or unknown packages and INACTIVE accounts; allows a new request after cancel', async () => {
    const m = await registerMember(ctx.api);
    await ownerQuery(`UPDATE package_types SET is_active = false WHERE id = $1`, [book2]);
    const na = await post(m.token, { packageTypeId: book2 });
    expect(na.status).toBe(422);
    expect(na.body.error.code).toBe('PACKAGE_NOT_AVAILABLE');
    await ownerQuery(`UPDATE package_types SET is_active = true WHERE id = $1`, [book2]);
    expect(
      (await post(m.token, { packageTypeId: '00000000-0000-4000-8000-000000000000' })).body.error.code,
    ).toBe('PACKAGE_NOT_AVAILABLE');

    await ownerQuery(`UPDATE members SET status = 'INACTIVE', status_since = now() WHERE user_id = $1`, [
      m.userId,
    ]);
    const blocked = await post(m.token, { packageTypeId: book2 });
    expect(blocked.status).toBe(403);
    expect(blocked.body.error.code).toBe('ACCOUNT_INACTIVE');
    await ownerQuery(`UPDATE members SET status = 'FROZEN', status_since = now() WHERE user_id = $1`, [
      m.userId,
    ]);

    const first = await post(m.token, { packageTypeId: book2 });
    expect(first.status).toBe(201); // FROZEN accounts may still ask; no active package -> null link
    expect(first.body.data.currentMembership).toBeNull();
    await ownerQuery(`UPDATE renewal_requests SET status = 'CANCELLED' WHERE id = $1`, [first.body.data.id]);
    expect((await post(m.token, { packageTypeId: book2 })).status).toBe(201);
  });

  it('lists the member history newest first, and the staff inbox with filters and paging', async () => {
    const a = await registerMember(ctx.api, { fullName: 'Alpha Inbox' });
    const b = await registerMember(ctx.api, { fullName: 'Bravo Inbox' });
    const r1 = await post(a.token, { packageTypeId: book2 });
    await ownerQuery(`UPDATE renewal_requests SET status = 'CANCELLED' WHERE id = $1`, [r1.body.data.id]);
    const r2 = await post(a.token, { packageTypeId: book2 });
    await post(b.token, { packageTypeId: book2 });

    const mine = await ctx.api.get('/api/v1/me/renewal-requests').set(bearer(a.token));
    expect(mine.body.data.map((r: { id: string }) => r.id)).toEqual([r2.body.data.id, r1.body.data.id]);
    expect(mine.body.meta).toMatchObject({ total: 2 });

    const pending = await ctx.api
      .get('/api/v1/renewal-requests?status=PENDING&q=inbox')
      .set(bearer(staffToken));
    expect(pending.status).toBe(200);
    expect(pending.body.data.map((r: { member: { fullName: string } }) => r.member.fullName).sort()).toEqual([
      'Alpha Inbox',
      'Bravo Inbox',
    ]);
    const byName = await ctx.api.get('/api/v1/renewal-requests?q=alpha&limit=1').set(bearer(staffToken));
    expect(byName.body.data).toHaveLength(1);
    expect(byName.body.meta).toMatchObject({ total: 2, limit: 1, totalPages: 2 });
  });
});
