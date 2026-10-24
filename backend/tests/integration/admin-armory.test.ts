import { randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('GFT-01 Admin gift and tier APIs', () => {
  let ctx: TestContext;
  let token: string;
  let adminId: string;
  const base = '/api/v1/admin/armory';
  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Gift Admin', phone: nextPhone() });
    adminId = admin.userId;
    token = (await login(ctx.api, admin.phone)).token;
  });
  async function createReward(patch: Record<string, unknown> = {}) {
    const result = await ctx.api.post(`${base}/rewards`).set(bearer(token)).send({ sku: `GFT-${randomUUID()}`, name: 'Test reward', marksCost: 120, ...patch });
    expect(result.status, JSON.stringify(result.body)).toBe(201);
    return result.body.data;
  }

  it('creates, edits and reads tiers with stable codes, audit and range validation', async () => {
    const created = await ctx.api.post(`${base}/tiers`).set(bearer(token)).send({ code: ' gft_test ', name: 'Test tier', minMarks: 50, maxMarks: 200 });
    expect(created.status).toBe(201);
    expect(created.body.data).toMatchObject({ code: 'GFT_TEST', sortOrder: 0 });
    const path = `${base}/tiers/GFT_TEST`;
    const updated = await ctx.api.patch(path).set(bearer(token)).send({ name: 'New tier name', maxMarks: null, reason: 'Open-ended tier' });
    expect(updated.status).toBe(200);
    expect(updated.body.data).toMatchObject({ name: 'New tier name', maxMarks: null });
    expect((await ctx.api.get(path).set(bearer(token))).body.data.name).toBe('New tier name');
    expect((await ctx.api.get(`${base}/tiers`).set(bearer(token))).body.data[0].code).toBe('GFT_TEST');
    const invalid = await ctx.api.patch(path).set(bearer(token)).send({ maxMarks: 20, reason: 'Bad range' });
    expect(invalid.status).toBe(400);
    expect(invalid.body.error.code).toBe('INVALID_TIER_RANGE');
    expect((await ctx.api.post(`${base}/tiers`).set(bearer(token)).send({ code: 'gft_test', name: 'Duplicate', minMarks: 0 })).status).toBe(409);
    const logs = await ctx.tx(() => sql.many<{ action: string; actorId: string }>(`SELECT action,actor_id FROM audit_logs WHERE entity_type='REWARD_TIER' AND entity_id='GFT_TEST' ORDER BY id`));
    expect(logs.map((log) => log.action)).toEqual(['REWARD_TIER_CREATED', 'REWARD_TIER_UPDATED']);
    expect(logs.every((log) => log.actorId === adminId)).toBe(true);
  });

  it('creates a gift with defaults and records initial inventory and audit atomically', async () => {
    const reward = await createReward({ stock: 5, tierCode: 'GFT_TEST' });
    expect(reward).toMatchObject({ stock: 5, isActive: true, description: null, perMemberLimit: null, limitPeriod: null });
    expect(reward.tenantId).toBeUndefined();
    expect((await ctx.api.get(`${base}/rewards/${reward.id}`).set(bearer(token))).status).toBe(200);
    const movement = await ctx.tx(() => sql.one<{ movementType: string; quantity: number; actorId: string }>('SELECT movement_type,quantity,actor_id FROM inventory_movements WHERE reward_id=$1', [reward.id]));
    expect(movement).toEqual({ movementType: 'IN', quantity: 5, actorId: adminId });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='REWARD_CREATED'`, [reward.id]))).toBe(1);
    const empty = await createReward();
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [empty.id]))).toBe(0);
  });

  it('edits stock, price and nullable metadata, with no-op retries producing no duplicate history', async () => {
    const reward = await createReward({ stock: 10, description: 'Original', tierCode: 'GFT_TEST' });
    const path = `${base}/rewards/${reward.id}`;
    const payload = { stock: 4, marksCost: 150, description: null, tierCode: null, isActive: false, reason: 'Stock correction' };
    const first = await ctx.api.patch(path).set(bearer(token)).send(payload);
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ stock: 4, marksCost: 150, description: null, tierCode: null, isActive: false });
    const second = await ctx.api.patch(path).set(bearer(token)).send(payload);
    expect(second.body.data.updatedAt).toBe(first.body.data.updatedAt);
    const movement = await ctx.tx(() => sql.many<{ movementType: string; quantity: number }>('SELECT movement_type,quantity FROM inventory_movements WHERE reward_id=$1 ORDER BY id', [reward.id]));
    expect(movement).toEqual([{ movementType: 'IN', quantity: 10 }, { movementType: 'OUT', quantity: 6 }]);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='REWARD_UPDATED'`, [reward.id]))).toBe(1);
  });

  it('validates merged dates, limit pairs, immutable identifiers and duplicate SKUs', async () => {
    const reward = await createReward({ saleStartsAt: '2026-10-01T00:00:00Z', saleEndsAt: '2026-11-01T00:00:00Z', perMemberLimit: 1, limitPeriod: 'MONTH' });
    const path = `${base}/rewards/${reward.id}`;
    expect((await ctx.api.patch(path).set(bearer(token)).send({ saleStartsAt: '2026-12-01T00:00:00Z', reason: 'Invalid dates' })).body.error.code).toBe('INVALID_REWARD_DATES');
    expect((await ctx.api.patch(path).set(bearer(token)).send({ limitPeriod: null, reason: 'Missing period' })).body.error.code).toBe('INVALID_REWARD_LIMIT');
    await ctx.api.patch(path).set(bearer(token)).send({ limitPeriod: null, perMemberLimit: null, reason: 'Clear limit' }).expect(200);
    for (const payload of [{ stock: -1 }, { sku: 'NEW_SKU' }, { isActive: 'false' }, {}]) {
      expect((await ctx.api.patch(path).set(bearer(token)).send({ ...payload, reason: 'Invalid payload' })).status).toBe(400);
    }
    expect((await ctx.api.post(`${base}/rewards`).set(bearer(token)).send({ sku: reward.sku.toLowerCase(), name: 'Duplicate', marksCost: 100 })).status).toBe(409);
    expect((await ctx.api.get(`${base}/rewards/${randomUUID()}`).set(bearer(token))).status).toBe(404);
    expect((await ctx.api.get(`${base}/tiers/MISSING`).set(bearer(token))).status).toBe(404);
  });

  it('searches, filters true/false correctly and paginates the Admin catalogue', async () => {
    await createReward({ name: 'FilterOnly active', isActive: true, tierCode: 'GFT_TEST' });
    await createReward({ name: 'FilterOnly disabled', isActive: false, tierCode: 'GFT_TEST' });
    const response = await ctx.api.get(`${base}/rewards`).set(bearer(token)).query({ q: 'FilterOnly', isActive: 'false', tierCode: 'GFT_TEST', limit: 1 });
    expect(response.status).toBe(200);
    expect(response.body.meta).toMatchObject({ page: 1, limit: 1, total: 1 });
    expect(response.body.data[0].name).toBe('FilterOnly disabled');
    expect((await ctx.api.get(`${base}/rewards?q=FilterOnly`).set(bearer(token))).body.meta.total).toBe(2);
    expect((await ctx.api.get(`${base}/rewards`).set(bearer(token)).query({ q: '%' })).body.meta.total).toBe(0);
    expect((await ctx.api.get(`${base}/rewards?isActive=invalid`).set(bearer(token))).status).toBe(400);
  });

  it('rejects foreign-tier/rank references, isolates objects and allows duplicate SKUs across tenants', async () => {
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign gift tenant')`, [tenant, tenant]);
    await ownerQuery(`INSERT INTO reward_tiers (tenant_id,code,name,min_marks,sort_order) VALUES ($1,'FOREIGN_TIER','Foreign tier',0,0)`, [tenant]);
    const [rank] = await ownerQuery<{ id: string }>(`INSERT INTO ranks (tenant_id,rank_order,code,name_en,dp_threshold) VALUES ($1,1,'FOREIGN','Foreign rank',0) RETURNING id`, [tenant]);
    const [foreign] = await ownerQuery<{ id: string }>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost) VALUES ($1,'SHARED_SKU','Foreign only gift',100) RETURNING id`, [tenant]);
    const reward = await createReward({ sku: 'SHARED_SKU' });
    const path = `${base}/rewards/${reward.id}`;
    expect((await ctx.api.patch(path).set(bearer(token)).send({ tierCode: 'FOREIGN_TIER', reason: 'Wrong tenant' })).body.error.code).toBe('INVALID_REWARD_TIER');
    expect((await ctx.api.patch(path).set(bearer(token)).send({ minRankId: rank.id, reason: 'Wrong tenant' })).body.error.code).toBe('INVALID_REWARD_RANK');
    expect((await ctx.api.get(`${base}/rewards/${foreign.id}`).set(bearer(token))).status).toBe(404);
    expect((await ctx.api.patch(`${base}/rewards/${foreign.id}`).set(bearer(token)).send({ name: 'Overwrite', reason: 'Wrong tenant' })).status).toBe(404);
    expect((await ctx.api.get(`${base}/rewards?q=Foreign only gift`).set(bearer(token))).body.data).toHaveLength(0);
    expect((await ctx.api.get(`${base}/tiers/FOREIGN_TIER`).set(bearer(token))).status).toBe(404);
  });

  it('keeps existing redemption price snapshots unchanged', async () => {
    const reward = await createReward();
    const member = await registerMember(ctx.api);
    const branchId = await ctx.tx(() => sql.scalar<string>('SELECT id FROM branches LIMIT 1'));
    const orderId = await ctx.tx(() => sql.scalar<string>(`INSERT INTO redemptions (tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key)
      VALUES ($1,$2,$3,$4,$5,120,$6) RETURNING id`, [ctx.tenantId, randomUUID(), member.userId, reward.id, branchId, randomUUID()]));
    await ctx.api.patch(`${base}/rewards/${reward.id}`).set(bearer(token)).send({ marksCost: 300, reason: 'New catalogue price' }).expect(200);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT marks_cost FROM redemptions WHERE id=$1', [orderId]))).toBe(120);
  });

  it('serializes stock edits with an inventory chain that reconciles to final stock', async () => {
    const reward = await createReward({ stock: 5 });
    const patch = (stock: number) => ctx.api.patch(`${base}/rewards/${reward.id}`).set(bearer(token)).send({ stock, reason: 'Concurrent stock edit' });
    const responses = await Promise.all([patch(8), patch(3)]);
    expect(responses.every((response) => response.status === 200)).toBe(true);
    const stock = await ctx.tx(() => sql.scalar<number>('SELECT stock FROM rewards WHERE id=$1', [reward.id]));
    const net = await ctx.tx(() => sql.scalar<number>(`SELECT SUM(CASE WHEN movement_type='IN' THEN quantity ELSE -quantity END)::int FROM inventory_movements WHERE reward_id=$1`, [reward.id]));
    expect(net).toBe(stock);
  });

  it('rolls back gift/stock/movement when audit cannot be recorded', async () => {
    const reward = await createReward({ stock: 4 });
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try {
      expect((await ctx.api.patch(`${base}/rewards/${reward.id}`).set(bearer(token)).send({ stock: 9, reason: 'Rollback test' })).status).toBe(500);
    } finally { spy.mockRestore(); }
    expect(await ctx.tx(() => sql.scalar<number>('SELECT stock FROM rewards WHERE id=$1', [reward.id]))).toBe(4);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [reward.id]))).toBe(1);
  });

  it('enforces Admin/Super Admin authorization for read and write APIs', async () => {
    expect((await ctx.api.get(`${base}/tiers`)).status).toBe(401);
    for (const role of ['COACH', 'HEAD_COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await ctx.api.get(`${base}/tiers`).set(bearer(session.token))).status).toBe(403);
      expect((await ctx.api.post(`${base}/tiers`).set(bearer(session.token)).send({ code: 'DENIED', name: 'Denied', minMarks: 0 })).status).toBe(403);
    }
    const member = await registerMember(ctx.api);
    expect((await ctx.api.get(`${base}/rewards`).set(bearer(member.token))).status).toBe(403);
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Super Admin', phone: nextPhone() });
    await ownerQuery(`UPDATE user_roles SET role_code='SUPER_ADMIN' WHERE user_id=$1`, [admin.userId]);
    const session = await login(ctx.api, admin.phone);
    expect((await ctx.api.post(`${base}/tiers`).set(bearer(session.token)).send({ code: 'SUPER_TIER', name: 'Super tier', minMarks: 0 })).status).toBe(201);
  });
});
