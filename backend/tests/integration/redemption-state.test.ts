import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-05 redemption transitions', () => {
  let ctx: TestContext;
  let member: { userId: string; token: string };
  let reception: string;
  let otherReception: string;
  let admin: string;
  let branchId: string;
  let rewardId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const r1 = await createStaff({ role: 'RECEPTIONIST', fullName: 'Q1', phone: nextPhone(), branchCode: 'Q1' });
    const r7 = await createStaff({ role: 'RECEPTIONIST', fullName: 'Q7', phone: nextPhone(), branchCode: 'Q7' });
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    reception = (await login(ctx.api, r1.phone)).token;
    otherReception = (await login(ctx.api, r7.phone)).token;
    admin = (await login(ctx.api, a.phone)).token;
    branchId = (await ctx.tx(() => sql.scalar<string>(`SELECT id FROM branches WHERE code='Q1'`)))!;
  });
  beforeEach(async () => {
    member = await registerMember(ctx.api);
    await ctx.tx(() => ctx.services.points.award({ memberId: member.userId, source: 'OPENING', marks: 300, note: 'Test balance' }));
    rewardId = (await ctx.tx(() => sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
      VALUES ($1,$2,'Reward',120,10) RETURNING id`, [ctx.tenantId, randomUUID()])))!;
  });
  async function create() {
    const response = await ctx.api.post('/api/v1/armory/redemptions').set(bearer(member.token)).send({ rewardId, pickupBranchId: branchId });
    expect(response.status).toBe(201);
    return response.body.data.redemption.id as string;
  }
  const decide = (id: string, token: string, body: object) => ctx.api.post(`/api/v1/staff/armory/redemptions/${id}/decision`).set(bearer(token)).send(body);
  const cancel = (id: string, token = member.token) => ctx.api.post(`/api/v1/me/armory/redemptions/${id}/cancel`).set(bearer(token)).send({});

  it('delivers once, uses ARM-04 debit and retains already deducted stock', async () => {
    const id = await create();
    const result = await decide(id, reception, { status: 'DELIVERED' });
    expect(result.status).toBe(200);
    expect(result.body.data.redemption.status).toBe('DELIVERED');
    expect((await decide(id, reception, { status: 'DELIVERED' })).body.data.duplicate).toBe(true);
    expect(await ctx.tx(() => ctx.services.points.wallet(member.userId))).toMatchObject({ marksBalance: 180, marksHeld: 0, marksAvailable: 180 });
    expect(await ctx.tx(() => sql.scalar('SELECT stock FROM rewards WHERE id=$1', [rewardId]))).toBe(9);
    expect(await ctx.tx(() => sql.scalar(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1 AND source='ARMORY_REDEEM'`, [id]))).toBe(1);
    expect((await cancel(id)).status).toBe(409);
  });

  it('rejects or cancels pending order once, releasing hold and restoring stock', async () => {
    const rejected = await create();
    expect((await decide(rejected, reception, { status: 'REJECTED', reason: 'Hàng lỗi' })).status).toBe(200);
    expect((await decide(rejected, reception, { status: 'REJECTED', reason: 'Hàng lỗi' })).body.data.duplicate).toBe(true);
    const cancelled = await create();
    expect((await cancel(cancelled)).status).toBe(200);
    expect((await cancel(cancelled)).body.data.duplicate).toBe(true);
    expect(await ctx.tx(() => ctx.services.points.wallet(member.userId))).toMatchObject({ marksBalance: 300, marksHeld: 0 });
    expect(await ctx.tx(() => sql.scalar('SELECT stock FROM rewards WHERE id=$1', [rewardId]))).toBe(10);
    expect(await ctx.tx(() => sql.scalar(`SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1 AND movement_type='IN'`, [rewardId]))).toBe(2);
    expect(await ctx.tx(() => sql.scalar(`SELECT count(*)::int FROM point_transactions WHERE redemption_id IN ($1,$2)`, [rejected, cancelled]))).toBe(0);
  });

  it('enforces owner, staff role, branch, tenant and request validation', async () => {
    const id = await create();
    const other = await registerMember(ctx.api);
    expect((await cancel(id, other.token)).status).toBe(404);
    expect((await decide(id, member.token, { status: 'DELIVERED' })).status).toBe(403);
    expect((await decide(id, otherReception, { status: 'DELIVERED' })).body.error.code).toBe('PICKUP_BRANCH_MISMATCH');
    expect((await decide(id, reception, { status: 'REJECTED' })).status).toBe(400);
    expect((await decide(id, reception, { status: 'EXPIRED' })).status).toBe(400);
    expect((await decide(randomUUID(), admin, { status: 'DELIVERED' })).status).toBe(404);
  });

  it('serializes concurrent competing decisions and rolls back on audit failure', async () => {
    const id = await create();
    const results = await Promise.all([decide(id, reception, { status: 'DELIVERED' }), cancel(id)]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    const second = await create();
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('audit failed'));
    try { expect((await decide(second, admin, { status: 'DELIVERED' })).status).toBe(500); } finally { spy.mockRestore(); }
    expect(await ctx.tx(() => sql.scalar('SELECT status FROM redemptions WHERE id=$1', [second]))).toBe('PENDING_PICKUP');
    expect(await ctx.tx(() => sql.scalar(`SELECT count(*)::int FROM point_transactions WHERE redemption_id=$1`, [second]))).toBe(0);
  });

  it('provides an internal EXPIRED transition that releases the hold once', async () => {
    const id = await create();
    const first = await ctx.tx(() => ctx.services.redemptions.expire(id, 'Pickup deadline expired'));
    const second = await ctx.tx(() => ctx.services.redemptions.expire(id, 'Pickup deadline expired'));
    expect(first.redemption.status).toBe('EXPIRED');
    expect(second.duplicate).toBe(true);
    expect(await ctx.tx(() => ctx.services.points.wallet(member.userId))).toMatchObject({ marksBalance: 300, marksHeld: 0 });
    expect(await ctx.tx(() => sql.scalar('SELECT stock FROM rewards WHERE id=$1', [rewardId]))).toBe(10);
  });
});
