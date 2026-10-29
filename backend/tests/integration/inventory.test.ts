import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('GFT-02 inventory movements', () => {
  let ctx: TestContext;
  let token: string;
  let actorId: string;
  let rewardId: string;
  const path = '/api/v1/staff/armory/inventory/movements';
  beforeAll(async () => {
    ctx = await bootTestApp();
    const staff = await createStaff({ role: 'RECEPTIONIST', fullName: 'Reception', phone: nextPhone() });
    actorId = staff.userId;
    token = (await login(ctx.api, staff.phone)).token;
  });
  beforeEach(async () => {
    rewardId = (await ctx.tx(() => sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
      VALUES ($1,$2,'Test reward',100,10) RETURNING id`, [ctx.tenantId, randomUUID()])))!;
  });
  const move = (movementType: string, quantity: number, reason = 'Kiểm kê kho') =>
    ctx.api.post(path).set(bearer(token)).send({ rewardId, movementType, quantity, reason });

  it('records IN and OUT with before/after stock, actor, audit and history', async () => {
    const first = await move('IN', 5);
    expect(first.status).toBe(201);
    expect(first.body.data).toMatchObject({ stockBefore: 10, stockAfter: 15, movement: { rewardId, movementType: 'IN', quantity: 5, actorId } });
    const second = await move('OUT', 4);
    expect(second.body.data).toMatchObject({ stockBefore: 15, stockAfter: 11 });
    const list = await ctx.api.get(path).set(bearer(token)).query({ rewardId, movementType: 'OUT', actorId, page: 1, limit: 1 });
    expect(list.status).toBe(200);
    expect(list.body.meta).toMatchObject({ total: 1, page: 1, limit: 1 });
    expect(list.body.data[0]).toMatchObject({ rewardId, rewardName: 'Test reward', movementType: 'OUT', actorId });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action IN ('INVENTORY_IN','INVENTORY_OUT')`, [rewardId]))).toBe(2);
  });

  it('prevents concurrent exports overspending stock', async () => {
    const results = await Promise.all([move('OUT', 7), move('OUT', 7)]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(results.find((r) => r.status === 409)!.body.error.code).toBe('INSUFFICIENT_STOCK');
    expect(await ctx.tx(() => sql.scalar('SELECT stock FROM rewards WHERE id=$1', [rewardId]))).toBe(3);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [rewardId]))).toBe(1);
  });

  it('rejects invalid body and date filters', async () => {
    for (const body of [{ rewardId, movementType: 'IN', quantity: 0, reason: 'Test' },
      { rewardId, movementType: 'OUT', quantity: -1, reason: 'Test' },
      { rewardId, movementType: 'IN', quantity: 1.5, reason: 'Test' },
      { rewardId, movementType: 'OUT', quantity: 1, reason: '' },
      { rewardId, movementType: 'OUT', quantity: 1, reason: 'Test', actorId }]) {
      expect((await ctx.api.post(path).set(bearer(token)).send(body)).status).toBe(400);
    }
    expect((await ctx.api.get(path).set(bearer(token)).query({ from: '2026-11-01T00:00:00Z', to: '2026-10-01T00:00:00Z' })).status).toBe(400);
    expect((await ctx.api.get(path).set(bearer(token)).query({ limit: 101 })).status).toBe(400);
  });

  it('enforces roles and tenant RLS for both modification and history', async () => {
    expect((await ctx.api.get(path)).status).toBe(401);
    const member = await registerMember(ctx.api);
    expect((await ctx.api.get(path).set(bearer(member.token))).status).toBe(403);
    const coach = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    const coachToken = (await login(ctx.api, coach.phone)).token;
    expect((await ctx.api.post(path).set(bearer(coachToken)).send({ rewardId, movementType: 'IN', quantity: 1, reason: 'Test' })).status).toBe(403);
    const tenant = randomUUID();
    await ownerQuery('INSERT INTO tenants (id,code,name) VALUES ($1,$2,$3)', [tenant, tenant, 'Foreign tenant']);
    const [foreign] = await ownerQuery<{ id: string }>('INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock) VALUES ($1,$2,$3,100,10) RETURNING id', [tenant, randomUUID(), 'Foreign']);
    expect((await ctx.api.post(path).set(bearer(token)).send({ rewardId: foreign.id, movementType: 'OUT', quantity: 1, reason: 'Test' })).status).toBe(404);
    expect((await ctx.api.get(path).set(bearer(token)).query({ rewardId: foreign.id })).body.data).toHaveLength(0);
  });

  it('rolls back stock and movement when audit fails', async () => {
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try { expect((await move('OUT', 2)).status).toBe(500); } finally { spy.mockRestore(); }
    expect(await ctx.tx(() => sql.scalar('SELECT stock FROM rewards WHERE id=$1', [rewardId]))).toBe(10);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [rewardId]))).toBe(0);
  });
});
