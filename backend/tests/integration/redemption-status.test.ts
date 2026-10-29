import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-05 redemption state machine', () => {
  let ctx: TestContext;
  let member: { userId: string; token: string };
  let adminToken: string;
  let receptionistQ1Token: string;
  let receptionistQ7Token: string;
  let q7: string;
  let rewardId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Armory Admin', phone: nextPhone() });
    adminToken = (await login(ctx.api, admin.phone)).token;
    const r1 = await createStaff({ role: 'RECEPTIONIST', fullName: 'Reception Q1', phone: nextPhone(), branchCode: 'Q1' });
    receptionistQ1Token = (await login(ctx.api, r1.phone)).token;
    const r7 = await createStaff({ role: 'RECEPTIONIST', fullName: 'Reception Q7', phone: nextPhone(), branchCode: 'Q7' });
    receptionistQ7Token = (await login(ctx.api, r7.phone)).token;
  });
  beforeEach(async () => {
    member = await registerMember(ctx.api);
    await ctx.tx(async () => {
      await ctx.services.points.award({ memberId: member.userId, source: 'OPENING', marks: 500, note: 'ARM-05 wallet fixture' });
      q7 = (await sql.scalar<string>(`SELECT id FROM branches WHERE code='Q7'`))!;
      rewardId = (await sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
        VALUES ($1,$2,'Status test reward',120,10) RETURNING id`, [ctx.tenantId, randomUUID()]))!;
    });
  });
  afterEach(resetClock);

  async function createOrder(branchId = q7, token = member.token) {
    const response = await ctx.api.post('/api/v1/armory/redemptions').set(bearer(token))
      .send({ rewardId, pickupBranchId: branchId });
    expect(response.status).toBe(201);
    return response.body.data.redemption as { id: string; marksCost: number; status: string };
  }
  const decision = (id: string, token: string, body: Record<string, unknown>) =>
    ctx.api.post(`/api/v1/staff/armory/redemptions/${id}/decision`).set(bearer(token)).send(body);
  const cancel = (id: string, body: Record<string, unknown> = {}) =>
    ctx.api.post(`/api/v1/me/armory/redemptions/${id}/cancel`).set(bearer(member.token)).send(body);
  const stock = () => ctx.tx(() => sql.scalar<number>('SELECT stock FROM rewards WHERE id=$1', [rewardId]));
  const wallet = () => ctx.tx(() => ctx.services.points.wallet(member.userId));

  it('lets the member cancel pending order, releasing only its hold and stock exactly once', async () => {
    const order = await createOrder();
    expect(await cancel(order.id, { reason: 'Cannot collect this week' })).toMatchObject({ status: 200 });
    const result = await cancel(order.id, { reason: 'Retry cancellation' });
    expect(result.body.data.duplicate).toBe(true);
    expect(result.body.data.redemption.status).toBe('CANCELLED');
    expect(await wallet()).toMatchObject({ marksBalance: 500, marksHeld: 0, marksAvailable: 500 });
    expect(await stock()).toBe(10);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE redemption_id=$1', [order.id]))).toBe(2);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1`, [order.id]))).toBe(0);
  });

  it('requires cancellation to have a pending status and keep ownership private', async () => {
    const order = await createOrder();
    const other = await registerMember(ctx.api);
    expect((await ctx.api.post(`/api/v1/me/armory/redemptions/${order.id}/cancel`).set(bearer(other.token)).send({})).status).toBe(404);
    const rejected = await decision(order.id, receptionistQ7Token, { status: 'REJECTED', reason: 'Damaged item' });
    expect(rejected.status).toBe(200);
    expect((await cancel(order.id)).body.error.code).toBe('REDEMPTION_NOT_CANCELLABLE');
    expect((await cancel(randomUUID())).status).toBe(404);
    expect((await cancel('bad-id')).status).toBe(400);
  });

  it('delivers at selected pickup branch, debits the Marks snapshot and notifies once', async () => {
    const order = await createOrder(q7);
    const wrongBranch = await decision(order.id, receptionistQ1Token, { status: 'DELIVERED' });
    expect(wrongBranch.status).toBe(403);
    expect(wrongBranch.body.error.code).toBe('PICKUP_BRANCH_MISMATCH');
    const delivered = await decision(order.id, receptionistQ7Token, { status: 'DELIVERED', reason: 'Handed to member', deliveryEvidenceUrl: 'https://example.test/receipt.jpg' });
    expect(delivered.status).toBe(200);
    expect(delivered.body.data.redemption).toMatchObject({ status: 'DELIVERED', reason: 'Handed to member' });
    expect(delivered.body.data.redemption.deliveryEvidenceUrl).toBe('https://example.test/receipt.jpg');
    const retried = await decision(order.id, receptionistQ7Token, { status: 'DELIVERED' });
    expect(retried.body.data.duplicate).toBe(true);
    expect(await wallet()).toMatchObject({ marksBalance: 380, marksHeld: 0, marksAvailable: 380 });
    expect(await stock()).toBe(9);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1 AND source='ARMORY_REDEEM'`, [order.id]))).toBe(1);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_type='REDEMPTION' AND entity_id=$1 AND action='REDEMPTION_DELIVERED'`, [order.id]))).toBe(1);
  });

  it('rejects at pickup branch, requires a reason, releases the hold and restores stock', async () => {
    const order = await createOrder(q7);
    const missingReason = await decision(order.id, receptionistQ7Token, { status: 'REJECTED' });
    expect(missingReason.status).toBe(400);
    const rejected = await decision(order.id, receptionistQ7Token, { status: 'REJECTED', reason: 'Out of stock on shelf' });
    expect(rejected.status).toBe(200);
    expect(rejected.body.data.redemption).toMatchObject({ status: 'REJECTED', reason: 'Out of stock on shelf' });
    expect(await wallet()).toMatchObject({ marksBalance: 500, marksHeld: 0, marksAvailable: 500 });
    expect(await stock()).toBe(10);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1`, [order.id]))).toBe(0);
  });

  it('allows Admin to decide any branch and rejects conflicting terminal transitions', async () => {
    const order = await createOrder(q7);
    expect((await decision(order.id, adminToken, { status: 'REJECTED', reason: 'Admin review rejected' })).status).toBe(200);
    const conflict = await decision(order.id, adminToken, { status: 'DELIVERED' });
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('REDEMPTION_ALREADY_FINAL');
  });

  it('expires pending orders in the server job hook, restoring stock and freeing held Marks', async () => {
    setClock(fixedClock(new Date('2026-10-01T12:00:00Z')));
    await ctx.tx(() => sql.exec('UPDATE rewards SET pickup_days=1 WHERE id=$1', [rewardId]));
    const order = await createOrder();
    setClock(fixedClock(new Date('2026-10-03T12:00:00Z')));
    const result = await ctx.tx(() => ctx.services.redemptions.expirePending());
    expect(result.expired).toBe(1);
    expect(await ctx.tx(() => sql.scalar('SELECT status FROM redemptions WHERE id=$1', [order.id]))).toBe('EXPIRED');
    expect(await wallet()).toMatchObject({ marksBalance: 500, marksHeld: 0 });
    expect(await stock()).toBe(10);
    expect((await ctx.tx(() => ctx.services.redemptions.expirePending())).expired).toBe(0);
  });

  it('rolls back delivered status and debit if audit fails', async () => {
    const order = await createOrder();
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try { expect((await decision(order.id, receptionistQ7Token, { status: 'DELIVERED' })).status).toBe(500); } finally { spy.mockRestore(); }
    expect(await ctx.tx(() => sql.scalar('SELECT status FROM redemptions WHERE id=$1', [order.id]))).toBe('PENDING_PICKUP');
    expect(await wallet()).toMatchObject({ marksBalance: 500, marksHeld: 120, marksAvailable: 380 });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1`, [order.id]))).toBe(0);
  });

  it('enforces actor permissions and validates transition payloads', async () => {
    const order = await createOrder();
    expect((await ctx.api.post(`/api/v1/staff/armory/redemptions/${order.id}/decision`).send({ status: 'DELIVERED' })).status).toBe(401);
    expect((await ctx.api.post(`/api/v1/staff/armory/redemptions/${order.id}/decision`).set(bearer(member.token)).send({ status: 'DELIVERED' })).status).toBe(403);
    for (const body of [{ status: 'PENDING_PICKUP' }, { status: 'REJECTED' }, { status: 'DELIVERED', tenantId: 'other' }]) {
      expect((await decision(order.id, receptionistQ7Token, body)).status).toBe(400);
    }
    expect((await ctx.api.post(`/api/v1/me/armory/redemptions/${order.id}/cancel`).send({})).status).toBe(401);
  });
});
