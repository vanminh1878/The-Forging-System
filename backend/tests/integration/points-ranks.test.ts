import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import { resetClock, setClock } from '../../src/common/utils/clock';
import type { TestContext } from '../helpers/test-app';

describe('points ledger & rank engine', () => {
  let ctx: TestContext;
  let memberId: string;
  let memberToken: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
  });

  afterEach(() => resetClock());

  beforeEach(async () => {
    clockOffsetDays = 0;
    const m = await registerMember(ctx.api);
    memberId = m.userId;
    memberToken = m.token;
  });

  const award = (source: string, dp: number, marks = 0, key?: string) =>
    ctx.tx(() => ctx.services.points.award({ memberId, source, dp, marks, note: 'test', idempotencyKey: key }));
  const adjust = (dpDelta: number, marksDelta = 0) =>
    ctx.tx(() => ctx.services.points.manualAdjust({ memberId, dpDelta, marksDelta, reason: 'test fixture', by: memberId, confirmed: true }));
  const rankOrder = async () => (await ctx.api.get('/api/v1/me/rank').set(bearer(memberToken))).body.data.current.rankOrder as number;
  const balances = async () =>
    (await ownerQuery<{ dp_balance: number; marks_balance: number }>('SELECT dp_balance, marks_balance FROM members WHERE user_id = $1', [memberId]))[0];
  /** Moves the engine clock forward; rank entry dates come from the DB, so this ages every gate. */
  let clockOffsetDays = 0;
  const advanceMonths = (months: number) => {
    clockOffsetDays += months * 30.44;
    setClock({ now: () => new Date(Date.now() + clockOffsetDays * 86_400_000) });
  };
  const completeCourse = async (code: string) => {
    const course = (await ownerQuery<{ id: string }>(`SELECT id FROM courses WHERE code = $1`, [code]))[0].id;
    await ownerQuery(
      `INSERT INTO course_enrollments (tenant_id, member_id, course_id, status, completed_at)
       SELECT tenant_id, user_id, $2, 'COMPLETED', now() FROM members WHERE user_id = $1`,
      [memberId, course],
    );
  };

  it('keeps the cached balance in sync with the ledger', async () => {
    await award('SESSION', 45, 15);
    await award('ATTITUDE', 10, 5);
    const b = await balances();
    expect(Number(b.dp_balance)).toBe(55);
    expect(Number(b.marks_balance)).toBe(20);
    const recon = await ctx.tx(() => ctx.services.points.reconcile(memberId));
    expect(recon).toMatchObject({ dpBalanceCache: 55, dpBalanceLedger: 55, marksBalanceCache: 20, marksBalanceLedger: 20 });
  });

  it('is idempotent: the same key never posts twice', async () => {
    const first = await award('SESSION', 40, 13, 'att-1');
    const second = await award('SESSION', 40, 13, 'att-1');
    expect(first.duplicate).toBe(false);
    expect(second.duplicate).toBe(true);
    expect(Number((await balances()).dp_balance)).toBe(40);
  });

  it('trims capped sources at the monthly cap but never RANK_TRIAL', async () => {
    await award('CHALLENGE', 1150);
    const capped = await award('SESSION', 100);
    expect(capped.transaction.dpAmount).toBe(50);
    const none = await award('ATTITUDE', 10);
    expect(none.transaction.dpAmount).toBe(0);
    await award('RANK_TRIAL', 150);
    expect(Number((await balances()).dp_balance)).toBe(1350);
    const monthly = await ctx.api.get('/api/v1/me/points/monthly').set(bearer(memberToken));
    expect(monthly.status).toBe(200);
  });

  it('refuses adjustments that would drive a balance negative', async () => {
    await expect(adjust(-10)).rejects.toMatchObject({ code: 'NEGATIVE_BALANCE' });
  });

  it('requires confirmation for large admin adjustments and reverses with a true opposite row', async () => {
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    const { token } = await login(ctx.api, admin.phone);
    const big = await ctx.api.post(`/api/v1/admin/members/${memberId}/points/adjust`).set(bearer(token)).send({ dpDelta: 800, reason: 'bonus' });
    expect(big.status).toBe(422);
    expect(big.body.error.code).toBe('CONFIRMATION_REQUIRED');

    const ok = await ctx.api.post(`/api/v1/admin/members/${memberId}/points/adjust`).set(bearer(token)).send({ dpDelta: 80, reason: 'bonus' });
    expect(ok.status).toBe(201);
    const txId = ok.body.data.transaction.id as string;
    const rev = await ctx.api.post(`/api/v1/admin/points/transactions/${txId}/reverse`).set(bearer(token)).send({ reason: 'mistake' });
    expect(rev.status).toBe(201);
    expect(Number((await balances()).dp_balance)).toBe(0);

    const forbidden = await ctx.api.post(`/api/v1/admin/members/${memberId}/points/adjust`).set(bearer(memberToken)).send({ dpDelta: 5, reason: 'self' });
    expect(forbidden.status).toBe(403);
  });

  it('makes posted ledger rows immutable at the database level', async () => {
    const { transaction } = await award('SESSION', 20);
    await expect(ownerQuery('UPDATE point_transactions SET dp_amount = 999 WHERE id = $1', [transaction.id])).rejects.toBeTruthy();
    await expect(ownerQuery('DELETE FROM point_transactions WHERE id = $1', [transaction.id])).rejects.toBeTruthy();
  });

  it('promotes automatically once DP and time-in-rank gates are both met', async () => {
    await adjust(500);
    expect(await rankOrder()).toBe(1); // reached rank I today: the 1-month gate blocks it
    advanceMonths(1.2);
    await adjust(1);
    expect(await rankOrder()).toBe(2);
    const badges = await ctx.api.get('/api/v1/me/badges').set(bearer(memberToken));
    expect(badges.status).toBe(200);
  });

  it('counts the waiting time from the current rank, not from joining', async () => {
    advanceMonths(1.2);
    await adjust(500);
    expect(await rankOrder()).toBe(2);
    await completeCourse('FOUNDATION');
    advanceMonths(2); // 3.2 months since joining, but only 2 at rank II (needs 3)
    await adjust(2500);
    const p = (await ctx.api.get('/api/v1/me/rank').set(bearer(memberToken))).body.data;
    expect(p.current.rankOrder).toBe(2);
    expect(p.timeOk).toBe(false);
    expect(p.monthsRemaining).toBeGreaterThan(0.5);
    advanceMonths(1.1);
    await adjust(1);
    expect(await rankOrder()).toBe(3); // rank III needs no trial anymore
  });

  it('runs promote -> demote -> restore without any trial up to rank III', async () => {
    advanceMonths(1.2);
    await adjust(500);
    await completeCourse('FOUNDATION');
    advanceMonths(3.2);
    await adjust(2000);
    expect(await rankOrder()).toBe(3);
    const progress = await ctx.api.get('/api/v1/me/rank').set(bearer(memberToken));
    expect(progress.body.data.trialRequired).toBe(false);

    // Fall under the rank III threshold: immediate demotion, badge revoked.
    await adjust(-300);
    expect(await rankOrder()).toBe(2);
    const badges = await ctx.api.get('/api/v1/me/badges').set(bearer(memberToken));
    expect(badges.body.data.map((b: { rankOrder: number }) => b.rankOrder)).not.toContain(3);
    const history = await ctx.api.get('/api/v1/me/rank-history').set(bearer(memberToken));
    expect(JSON.stringify(history.body.data)).toContain('AUTO_DEMOTE');

    // Climb back: restored straight away, no trial and no new waiting period.
    await adjust(300);
    expect(await rankOrder()).toBe(3);
    const after = await ctx.api.get('/api/v1/me/rank-history').set(bearer(memberToken));
    expect(JSON.stringify(after.body.data)).toContain('RESTORED');
  });

  it('keeps the coach trial for rank VI: a failed trial leaves the rank unchanged, a pass promotes', async () => {
    const rank5 = (await ownerQuery<{ id: string }>(`SELECT id FROM ranks WHERE rank_order = 5`))[0].id;
    await ownerQuery(`UPDATE members SET current_rank_id = $2, peak_rank_id = $2 WHERE user_id = $1`, [memberId, rank5]);
    await completeCourse('THE_FIGHTER');
    await adjust(15000);
    const p = (await ctx.api.get('/api/v1/me/rank').set(bearer(memberToken))).body.data;
    expect(p.status).toBe('TRIAL_REQUIRED'); // DP is enough, rank VI has no waiting period

    const req = await ctx.api.post('/api/v1/me/rank-trials').set(bearer(memberToken));
    expect(req.status).toBe(201);
    expect(req.body.data.approverRole).toBe('COACH');
    const coach = await createStaff({ role: 'COACH', fullName: 'Coach 2', phone: nextPhone() });
    const { token } = await login(ctx.api, coach.phone);

    const fail = await ctx.api.post(`/api/v1/rank-trials/${req.body.data.id}/decision`).set(bearer(token)).send({ result: 'FAIL' });
    expect(fail.body.data.status).toBe('FAILED');
    expect(await rankOrder()).toBe(5);

    const again = await ctx.api.post('/api/v1/me/rank-trials').set(bearer(memberToken));
    const pass = await ctx.api.post(`/api/v1/rank-trials/${again.body.data.id}/decision`).set(bearer(token)).send({ result: 'PASS' });
    expect(pass.body.data.status).toBe('PASSED');
    expect(await rankOrder()).toBe(6);
  });
});
