import { afterEach, beforeAll, describe, expect, it } from 'vitest';
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

describe('activate / renew package (MEM-04)', () => {
  let ctx: TestContext;
  let staff: string;
  let coach: string;
  let book1: string;
  let book2: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const mk = async (role: string) =>
      (await login(ctx.api, (await createStaff({ role, fullName: role, phone: nextPhone() } as never)).phone))
        .token;
    staff = await mk('RECEPTIONIST');
    coach = await mk('COACH');
    const id = async (code: string) =>
      (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = $1`, [code]))[0].id;
    book1 = await id('BOOK_1');
    book2 = await id('BOOK_2');
  });
  afterEach(() => resetClock());

  const activate = (token: string, memberId: string, body: object) =>
    ctx.api.post(`/api/v1/members/${memberId}/memberships`).set(bearer(token)).send(body);
  const approve = (token: string, id: string, body: object) =>
    ctx.api.post(`/api/v1/renewal-requests/${id}/approve`).set(bearer(token)).send(body);
  const setStatus = (memberId: string, status: string) =>
    ownerQuery(`UPDATE members SET status = $2, status_since = now() WHERE user_id = $1`, [memberId, status]);

  it('enforces auth, roles and evidence validation', async () => {
    const m = await registerMember(ctx.api);
    const url = `/api/v1/members/${m.userId}/memberships`;
    expect((await ctx.api.post(url).send({ packageTypeId: book1 })).status).toBe(401);
    expect(
      (await activate(coach, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE })).status,
    ).toBe(403);
    expect(
      (await activate(m.token, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE })).status,
    ).toBe(403);
    expect((await activate(staff, m.userId, { packageTypeId: 'x' })).status).toBe(400);
    const none = await activate(staff, m.userId, { packageTypeId: book1 });
    expect([none.status, none.body.error.code]).toEqual([400, 'PAYMENT_EVIDENCE_REQUIRED']);
    const bad = await activate(staff, m.userId, {
      packageTypeId: book1,
      paymentEvidenceUrl: 'https://evil.test/a.jpg',
    });
    expect([bad.status, bad.body.error.code]).toEqual([400, 'INVALID_PAYMENT_EVIDENCE']);
    expect(
      (
        await ctx.api
          .post('/api/v1/renewal-requests/' + m.userId + '/approve')
          .set(bearer(coach))
          .send({})
      ).status,
    ).toBe(403);
  });

  it('activates from today, reactivates a FROZEN member, then queues a follow-on package', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    await setStatus(m.userId, 'FROZEN');
    const a = await activate(staff, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE });
    expect(a.status).toBe(201);
    expect(a.body.data).toMatchObject({ mode: 'ACTIVATED', reactivated: true });
    expect(a.body.data.message).toContain('tài khoản được mở lại');
    expect(a.body.data.membership).toMatchObject({
      status: 'ACTIVE',
      startDate: '2026-10-24',
      endDate: '2027-01-15', // 84 days
      paymentEvidenceUrl: EVIDENCE,
    });
    expect(
      (await ownerQuery<{ status: string }>(`SELECT status FROM members WHERE user_id = $1`, [m.userId]))[0]
        .status,
    ).toBe('ACTIVE');

    const b = await activate(staff, m.userId, { packageTypeId: book2, paymentEvidenceUrl: EVIDENCE });
    expect(b.body.data).toMatchObject({ mode: 'SCHEDULED', reactivated: false });
    expect(b.body.data.membership.startDate).toBe('2027-01-16');
    expect(b.body.data.message).toBe(
      'Gia hạn sớm: gói mới xếp nối tiếp từ 16/01/2027, học viên nhận +50 Marks (1 lần cho mỗi gói).',
    );
    const row = (
      await ownerQuery<{ previous_membership_id: string; price_paid_vnd: string }>(
        `SELECT previous_membership_id, price_paid_vnd FROM memberships WHERE id = $1`,
        [b.body.data.membership.id],
      )
    )[0];
    expect(row.previous_membership_id).toBe(a.body.data.membership.id);
    expect(Number(row.price_paid_vnd)).toBe(9_800_000);

    const c = await activate(staff, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE });
    expect([c.status, c.body.error.code]).toEqual([409, 'MEMBERSHIP_ALREADY_SCHEDULED']);

    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'MEMBERSHIP_CREATED' AND entity_id = $1`, [
        a.body.data.membership.id,
      ]),
    ).toHaveLength(1);
    expect(
      await ownerQuery(
        `SELECT 1 FROM notifications WHERE user_id = $1 AND event_type = 'RENEWAL_COMPLETED'`,
        [m.userId],
      ),
    ).toHaveLength(2);

    // Reception sees the proof, the learner does not.
    const fd = await ctx.api.get(`/api/v1/members/${m.userId}/membership`).set(bearer(staff));
    expect(fd.body.data.current.paymentEvidenceUrl).toBe(EVIDENCE);
    const me = await ctx.api.get('/api/v1/me/membership').set(bearer(m.token));
    expect(me.body.data.current).not.toHaveProperty('paymentEvidenceUrl');
  });

  it('replaces an expired ACTIVE package (edge: last day is still valid)', async () => {
    const m = await registerMember(ctx.api);
    const old = await ownerQuery<{ id: string }>(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions)
       SELECT m.tenant_id, m.user_id, pt.id, '2026-07-01', '2026-10-23', 36 FROM members m, package_types pt
        WHERE m.user_id = $1 AND pt.code = 'BOOK_1' RETURNING id`,
      [m.userId],
    );
    setClock(fixedClock(new Date('2026-10-23T05:00:00Z'))); // last day -> still valid -> SCHEDULED
    const early = await activate(staff, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE });
    expect(early.body.data.mode).toBe('SCHEDULED');
    expect(early.body.data.membership.startDate).toBe('2026-10-24');
    await ownerQuery(`UPDATE memberships SET status = 'CANCELLED' WHERE id = $1`, [early.body.data.membership.id]); // ledger row keeps the FK

    setClock(fixedClock(new Date('2026-10-24T05:00:00Z'))); // day after -> expired -> ACTIVE
    const res = await activate(staff, m.userId, { packageTypeId: book1, paymentEvidenceUrl: EVIDENCE });
    expect(res.body.data.mode).toBe('ACTIVATED');
    const o = (
      await ownerQuery<{ status: string; expired_at: Date | null }>(
        `SELECT status, expired_at FROM memberships WHERE id = $1`,
        [old[0].id],
      )
    )[0];
    expect(o.status).toBe('EXPIRED');
    expect(o.expired_at).not.toBeNull();
    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'MEMBERSHIP_EXPIRED' AND entity_id = $1`, [
        old[0].id,
      ]),
    ).toHaveLength(1);
  });

  it('rejects inactive and unknown packages', async () => {
    const m = await registerMember(ctx.api);
    await ownerQuery(`UPDATE package_types SET is_active = false WHERE id = $1`, [book2]);
    const r = await activate(staff, m.userId, { packageTypeId: book2, paymentEvidenceUrl: EVIDENCE });
    await ownerQuery(`UPDATE package_types SET is_active = true WHERE id = $1`, [book2]);
    expect([r.status, r.body.error.code]).toEqual([422, 'PACKAGE_INACTIVE']);
    expect(
      (
        await activate(staff, m.userId, {
          packageTypeId: '00000000-0000-4000-8000-000000000000',
          paymentEvidenceUrl: EVIDENCE,
        })
      ).status,
    ).toBe(404);
  });

  it('approves a renewal request once, then 409', async () => {
    const m = await registerMember(ctx.api);
    const rr = await ctx.api
      .post('/api/v1/me/renewal-requests')
      .set(bearer(m.token))
      .send({ packageTypeId: book2 });
    const id = rr.body.data.id;
    expect((await approve(staff, id, {})).body.error.code).toBe('PAYMENT_EVIDENCE_REQUIRED');
    expect((await approve(m.token, id, { paymentEvidenceUrl: EVIDENCE })).status).toBe(403);
    expect(
      (await approve(staff, '00000000-0000-4000-8000-000000000000', { paymentEvidenceUrl: EVIDENCE })).status,
    ).toBe(404);

    const ok = await approve(staff, id, { paymentEvidenceUrl: EVIDENCE, note: 'thu tiền mặt' });
    expect(ok.status).toBe(200);
    expect(ok.body.data.membership.packageType.id).toBe(book2);
    const row = (
      await ownerQuery<{
        status: string;
        resulting_membership_id: string;
        payment_evidence_url: string;
        handled_by: string;
      }>(
        `SELECT status, resulting_membership_id, payment_evidence_url, handled_by FROM renewal_requests WHERE id = $1`,
        [id],
      )
    )[0];
    expect(row).toMatchObject({
      status: 'COMPLETED',
      resulting_membership_id: ok.body.data.membership.id,
      payment_evidence_url: EVIDENCE,
    });
    expect(row.handled_by).toBeTruthy();
    expect(
      await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'RENEWAL_COMPLETED' AND entity_id = $1`, [
        id,
      ]),
    ).toHaveLength(1);

    const again = await approve(staff, id, { paymentEvidenceUrl: EVIDENCE });
    expect([again.status, again.body.error.code]).toEqual([409, 'RENEWAL_ALREADY_HANDLED']);
  });
});
