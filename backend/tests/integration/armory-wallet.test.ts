import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { db } from '../../src/db/database';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-04 wallet, holds and ledger debit', () => {
  let ctx: TestContext;
  let memberId: string;
  let token: string;
  let rewardId: string;
  let branchId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    await ctx.tx(async () => {
      branchId = (await sql.scalar<string>('SELECT id FROM branches LIMIT 1'))!;
      rewardId = (await sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock) VALUES ($1,'HOLD_TEST','Hold test',120,100) RETURNING id`, [ctx.tenantId]))!;
    });
  });
  beforeEach(async () => {
    const member = await registerMember(ctx.api);
    memberId = member.userId;
    token = member.token;
    await ctx.tx(() => ctx.services.points.award({ memberId, source: 'OPENING', marks: 300, note: 'Opening balance' }));
  });

  async function insertHold(cost: number) {
    await ctx.services.points.assertMarksAvailable(memberId, cost);
    return (await sql.one<{ id: string; marksCost: number }>(`INSERT INTO redemptions
      (tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key)
      VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id,marks_cost`, [ctx.tenantId, randomUUID(), memberId, rewardId, branchId, cost, randomUUID()]))!;
  }
  const hold = (cost: number) => ctx.tx(() => insertHold(cost));
  const wallet = () => ctx.tx(() => ctx.services.points.wallet(memberId));
  const deliver = (order: { id: string; marksCost: number }, key?: string) => ctx.tx(async () => {
    const result = await ctx.services.points.award({ memberId, source: 'ARMORY_REDEEM', marks: -order.marksCost, redemptionId: order.id, note: 'Delivery', idempotencyKey: key });
    await sql.exec(`UPDATE redemptions SET status='DELIVERED',decided_at=now() WHERE id=$1`, [order.id]);
    return result;
  });

  it('shows held/available Marks and releases holds without ledger mutations', async () => {
    const first = await hold(120);
    const second = await hold(80);
    const response = await ctx.api.get('/api/v1/me/armory/wallet').set(bearer(token));
    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({ memberId, marksBalance: 300, marksHeld: 200, marksAvailable: 100, canRedeem: true });
    await ctx.tx(() => sql.exec(`UPDATE redemptions SET status='REJECTED' WHERE id=$1`, [first.id]));
    await ctx.tx(() => sql.exec(`UPDATE redemptions SET status='EXPIRED' WHERE id=$1`, [second.id]));
    expect(await wallet()).toMatchObject({ marksBalance: 300, marksHeld: 0, marksAvailable: 300 });
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM point_transactions WHERE member_id=$1', [memberId]))).toBe(1);
  });

  it('converts its own hold to one debit and preserves other holds and monthly cap', async () => {
    const first = await hold(120);
    await hold(80);
    const result = await deliver(first);
    expect(result).toMatchObject({ duplicate: false, transaction: { dpAmount: 0, marksAmount: -120, isCapped: false } });
    expect(await wallet()).toMatchObject({ marksBalance: 180, marksHeld: 80, marksAvailable: 100 });
    expect(await ctx.tx(() => ctx.services.points.monthlyStatus(memberId))).toMatchObject({ marksUsed: 0, dpUsed: 0 });
    expect(await ctx.tx(() => ctx.services.points.reconcile(memberId))).toMatchObject({ marksBalanceCache: 180, marksBalanceLedger: 180 });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE action='ARMORY_MARKS_DEBITED' AND entity_id=$1`, [result.transaction.id]))).toBe(1);
  });

  it('does not double debit when retrying concurrently or with a different key', async () => {
    const order = await hold(300);
    const [first, second] = await Promise.all([deliver(order), deliver(order)]);
    expect(first.transaction.id).toBe(second.transaction.id);
    expect([first.duplicate, second.duplicate].sort()).toEqual([false, true]);
    expect((await deliver(order, 'different-retry-key')).transaction.id).toBe(first.transaction.id);
    expect(await wallet()).toMatchObject({ marksBalance: 0, marksHeld: 0 });
  });

  it('serializes concurrent new holds so only one can spend the available amount', async () => {
    const results = await Promise.allSettled([hold(180), hold(180)]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);
    expect(await wallet()).toMatchObject({ marksBalance: 300, marksHeld: 180, marksAvailable: 120 });
  });

  it('validates order snapshots/status, negative award sources and member ownership', async () => {
    const order = await hold(120);
    await expect(ctx.tx(() => ctx.services.points.award({ memberId, source: 'ARMORY_REDEEM', marks: -100, redemptionId: order.id, note: 'Wrong cost' }))).rejects.toMatchObject({ code: 'REDEMPTION_AMOUNT_MISMATCH' });
    const other = await registerMember(ctx.api);
    await expect(ctx.tx(() => ctx.services.points.award({ memberId: other.userId, source: 'ARMORY_REDEEM', marks: -120, redemptionId: order.id, note: 'Wrong member' }))).rejects.toMatchObject({ status: 404 });
    await expect(ctx.tx(() => ctx.services.points.award({ memberId, source: 'SESSION', marks: -10, note: 'Invalid debit' }))).rejects.toMatchObject({ code: 'INVALID_AWARD' });
    await ctx.tx(() => sql.exec(`UPDATE redemptions SET status='CANCELLED' WHERE id=$1`, [order.id]));
    await expect(deliver(order)).rejects.toMatchObject({ code: 'REDEMPTION_NOT_PAYABLE' });
    expect(await wallet()).toMatchObject({ marksBalance: 300, marksHeld: 0 });
  });

  it('protects pending Marks from manual adjustment and reversal', async () => {
    await hold(120);
    await expect(ctx.tx(() => ctx.services.points.manualAdjust({ memberId, dpDelta: 0, marksDelta: -200, by: memberId, reason: 'Would consume hold' }))).rejects.toMatchObject({ code: 'INSUFFICIENT_AVAILABLE_MARKS' });
    const grant = await ctx.tx(() => ctx.services.points.award({ memberId, source: 'SESSION', marks: 100, note: 'Granted' }));
    await hold(230);
    await expect(ctx.tx(() => ctx.services.points.reverse({ transactionId: grant.transaction.id, by: memberId, reason: 'Would consume hold' }))).rejects.toMatchObject({ code: 'INSUFFICIENT_AVAILABLE_MARKS' });
    expect(await wallet()).toMatchObject({ marksBalance: 400, marksHeld: 350, marksAvailable: 50 });
  });

  it('allows FROZEN but blocks new holds for INACTIVE members', async () => {
    await ctx.tx(() => sql.exec(`UPDATE members SET status='FROZEN',status_since=now() WHERE user_id=$1`, [memberId]));
    await hold(100);
    expect(await wallet()).toMatchObject({ canRedeem: true, marksHeld: 100 });
    await ctx.tx(() => sql.exec(`UPDATE members SET status='INACTIVE' WHERE user_id=$1`, [memberId]));
    expect(await wallet()).toMatchObject({ canRedeem: false });
    await expect(hold(1)).rejects.toMatchObject({ code: 'MEMBER_INACTIVE' });
  });

  it('rolls back a debit if audit fails', async () => {
    const order = await hold(120);
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit failed'));
    try { await expect(deliver(order)).rejects.toThrow('Audit failed'); } finally { spy.mockRestore(); }
    expect(await wallet()).toMatchObject({ marksBalance: 300, marksHeld: 120, marksAvailable: 180 });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1`, [order.id]))).toBe(0);
  });

  it('requires a member token and protects wallet reads under RLS', async () => {
    expect((await ctx.api.get('/api/v1/me/armory/wallet')).status).toBe(401);
    const staff = await createStaff({ role: 'RECEPTIONIST', fullName: 'Staff', phone: nextPhone() });
    const session = await login(ctx.api, staff.phone);
    expect((await ctx.api.get('/api/v1/me/armory/wallet').set(bearer(session.token))).status).toBe(403);
    const foreignTenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign')`, [foreignTenant, foreignTenant]);
    await expect(db.tenantTx(foreignTenant, () => ctx.services.points.wallet(memberId))).rejects.toMatchObject({ status: 404 });
  });

  it('keeps account merging compatible with signed manual transfers and moved holds', async () => {
    const keep = await registerMember(ctx.api);
    await hold(120);
    await ctx.tx(() => ctx.services.members.merge({ keepId: keep.userId, dropId: memberId, by: keep.userId }));
    expect(await ctx.tx(() => ctx.services.points.wallet(keep.userId))).toMatchObject({ marksBalance: 300, marksHeld: 120, marksAvailable: 180 });
    expect(await wallet()).toMatchObject({ marksBalance: 0, marksHeld: 0 });
  });
});
