import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { env } from '../../src/config/env';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

const EVIDENCE = `${env.PUBLIC_BASE_URL}/files/evidence/abc.jpg`;
const ZERO = '00000000-0000-4000-8000-000000000000';

describe('cancel renewal request / membership (MEM-06)', () => {
  let ctx: TestContext;
  let staff: string;
  let admin: string;
  let coach: string;
  let book1: string;
  let book2: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const mk = async (role: string) =>
      (await login(ctx.api, (await createStaff({ role, fullName: role, phone: nextPhone() } as never)).phone)).token;
    staff = await mk('RECEPTIONIST');
    admin = await mk('ADMIN');
    coach = await mk('COACH');
    const id = async (code: string) =>
      (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = $1`, [code]))[0].id;
    book1 = await id('BOOK_1');
    book2 = await id('BOOK_2');
  });
  afterEach(() => resetClock());

  const activate = (memberId: string, packageTypeId: string) =>
    ctx.api
      .post(`/api/v1/members/${memberId}/memberships`)
      .set(bearer(staff))
      .send({ packageTypeId, paymentEvidenceUrl: EVIDENCE });
  const cancelMs = (token: string, id: string, body: object = { reason: 'Sai gói' }) =>
    ctx.api.post(`/api/v1/memberships/${id}/cancel`).set(bearer(token)).send(body);
  const cancelRr = (token: string, id: string, body: object = { reason: 'Học viên đổi ý' }) =>
    ctx.api.post(`/api/v1/renewal-requests/${id}/cancel`).set(bearer(token)).send(body);
  const marks = async (memberId: string) =>
    (await ownerQuery<{ marks_balance: number }>(`SELECT marks_balance FROM members WHERE user_id = $1`, [memberId]))[0]
      .marks_balance;
  const memberStatus = async (memberId: string) =>
    (await ownerQuery<{ status: string }>(`SELECT status FROM members WHERE user_id = $1`, [memberId]))[0].status;

  it('cancels a pending renewal request once and notifies the learner', async () => {
    const m = await registerMember(ctx.api);
    const rr = await ctx.api.post('/api/v1/me/renewal-requests').set(bearer(m.token)).send({ packageTypeId: book2 });
    const id = rr.body.data.id;
    expect((await ctx.api.post(`/api/v1/renewal-requests/${id}/cancel`).send({ reason: 'x' })).status).toBe(401);
    expect((await cancelRr(coach, id)).status).toBe(403);
    expect((await cancelRr(m.token, id)).status).toBe(403);
    expect((await cancelRr(staff, 'x')).status).toBe(400);
    const none = await cancelRr(staff, id, { reason: '  ' });
    expect([none.status, none.body.error.code]).toEqual([400, 'CANCEL_REASON_REQUIRED']);
    expect((await cancelRr(staff, ZERO)).status).toBe(404);

    const ok = await cancelRr(staff, id);
    expect(ok.status).toBe(200);
    expect(ok.body.data).toMatchObject({ status: 'CANCELLED', reason: 'Học viên đổi ý' });
    const n = await ownerQuery<{ title: string; body: string }>(
      `SELECT title, body FROM notifications WHERE user_id = $1 AND event_type = 'RENEWAL_CANCELLED'`,
      [m.userId],
    );
    expect(n).toEqual([{ title: 'YÊU CẦU GIA HẠN BỊ HUỶ', body: 'Yêu cầu gia hạn đã bị huỷ. Lý do: Học viên đổi ý.' }]);
    expect(await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'RENEWAL_CANCELLED' AND entity_id = $1`, [id])).toHaveLength(1);
    const again = await cancelRr(staff, id);
    expect([again.status, again.body.error.code]).toEqual([409, 'RENEWAL_ALREADY_HANDLED']);
  });

  it('cancels a SCHEDULED package, takes back the bonus, and the next renewal earns it again', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    await activate(m.userId, book1);
    const b = await activate(m.userId, book2);
    const id = b.body.data.membership.id;
    expect(await marks(m.userId)).toBe(50);

    expect((await ctx.api.post(`/api/v1/memberships/${id}/cancel`).send({ reason: 'x' })).status).toBe(401);
    expect((await cancelMs(coach, id)).status).toBe(403);
    expect((await cancelMs(staff, 'x')).status).toBe(400);
    expect((await cancelMs(staff, id, {})).body.error.code).toBe('CANCEL_REASON_REQUIRED');
    expect((await cancelMs(staff, ZERO)).status).toBe(404);

    const res = await cancelMs(staff, id);
    expect(res.status).toBe(200);
    expect(res.body.data.membership.status).toBe('CANCELLED');
    expect(await marks(m.userId)).toBe(0);
    const row = (
      await ownerQuery<{ cancelled_by: string; cancel_reason: string }>(
        `SELECT cancelled_by, cancel_reason FROM memberships WHERE id = $1`,
        [id],
      )
    )[0];
    expect(row.cancel_reason).toBe('Sai gói');
    expect(row.cancelled_by).toBeTruthy();
    expect(await memberStatus(m.userId)).toBe('ACTIVE'); // current package still running
    expect(
      await ownerQuery(`SELECT 1 FROM notifications WHERE user_id = $1 AND event_type = 'MEMBERSHIP_STATUS'`, [m.userId]),
    ).toHaveLength(1);
    expect(await ownerQuery(`SELECT 1 FROM audit_logs WHERE action = 'MEMBERSHIP_CANCELLED' AND entity_id = $1`, [id])).toHaveLength(1);

    const second = await cancelMs(staff, id);
    expect([second.status, second.body.error.code]).toEqual([409, 'MEMBERSHIP_NOT_CANCELLABLE']);

    const c = await activate(m.userId, book2);
    expect(c.body.data.bonusMarks).toBe(50);
    expect(await marks(m.userId)).toBe(50);
  });

  it('lets only admins cancel an ACTIVE package, after the SCHEDULED one, and freezes the member', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    const a = await activate(m.userId, book1);
    const activeId = a.body.data.membership.id;
    const denied = await cancelMs(staff, activeId);
    expect([denied.status, denied.body.error.code]).toEqual([403, 'ADMIN_ONLY']);

    const b = await activate(m.userId, book2);
    const blocked = await cancelMs(admin, activeId);
    expect([blocked.status, blocked.body.error.code]).toEqual([409, 'CANCEL_SCHEDULED_FIRST']);
    expect((await cancelMs(staff, b.body.data.membership.id)).status).toBe(200);

    expect((await cancelMs(admin, activeId)).status).toBe(200);
    expect(await memberStatus(m.userId)).toBe('FROZEN');
  });

  it('refuses to reverse a bonus that was already spent (422) and keeps everything unchanged', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    await activate(m.userId, book1);
    const b = await activate(m.userId, book2);
    await ownerQuery(
      `INSERT INTO point_transactions (tenant_id, member_id, source, dp_amount, marks_amount, note)
       SELECT tenant_id, user_id, 'ARMORY_REDEEM', 0, -30, 'spent' FROM members WHERE user_id = $1`,
      [m.userId],
    );
    const res = await cancelMs(staff, b.body.data.membership.id);
    expect([res.status, res.body.error.code]).toEqual([422, 'BONUS_ALREADY_SPENT']);
    expect(
      (await ownerQuery<{ status: string }>(`SELECT status FROM memberships WHERE id = $1`, [b.body.data.membership.id]))[0].status,
    ).toBe('SCHEDULED');
    expect(await marks(m.userId)).toBe(20);
  });

  it('rejects cancelling an EXPIRED package', async () => {
    const m = await registerMember(ctx.api);
    const old = await ownerQuery<{ id: string }>(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, status)
       SELECT m.tenant_id, m.user_id, pt.id, '2026-01-01', '2026-03-01', 36, 'EXPIRED' FROM members m, package_types pt
        WHERE m.user_id = $1 AND pt.code = 'BOOK_1' RETURNING id`,
      [m.userId],
    );
    const res = await cancelMs(admin, old[0].id);
    expect([res.status, res.body.error.code]).toEqual([409, 'MEMBERSHIP_NOT_CANCELLABLE']);
  });
});
