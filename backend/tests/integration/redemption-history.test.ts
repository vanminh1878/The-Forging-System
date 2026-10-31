import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-03 redemption history', () => {
  let ctx: TestContext;
  let member: { userId: string; token: string };
  let other: { userId: string; token: string };
  let rewardId: string;
  let branchId: string;
  const base = '/api/v1/me/armory/redemptions';

  beforeAll(async () => { ctx = await bootTestApp(); });
  beforeEach(async () => {
    member = await registerMember(ctx.api);
    other = await registerMember(ctx.api);
    await ctx.tx(async () => {
      await ctx.services.points.award({ memberId: member.userId, source: 'OPENING', marks: 500, note: 'History test' });
      await ctx.services.points.award({ memberId: other.userId, source: 'OPENING', marks: 500, note: 'History test' });
      branchId = (await sql.scalar<string>('SELECT id FROM branches ORDER BY code LIMIT 1'))!;
      rewardId = (await sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
        VALUES ($1,$2,'History gift',100,20) RETURNING id`, [ctx.tenantId, randomUUID()]))!;
    });
  });

  async function create(user: { token: string }) {
    const response = await ctx.api.post('/api/v1/armory/redemptions').set(bearer(user.token)).send({ rewardId, pickupBranchId: branchId });
    expect(response.status).toBe(201);
    return response.body.data.redemption as { id: string };
  }

  it('returns only the authenticated member orders with price snapshot and branch', async () => {
    const order = await create(member);
    await create(other);
    await ctx.tx(() => sql.exec('UPDATE rewards SET marks_cost=250 WHERE id=$1', [rewardId]));
    const result = await ctx.api.get(base).set(bearer(member.token));
    expect(result.status).toBe(200);
    expect(result.body.meta.total).toBe(1);
    expect(result.body.data[0]).toMatchObject({ id: order.id, rewardId, rewardName: 'History gift', marksCost: 100, status: 'PENDING_PICKUP', pickupBranchId: branchId });
    expect(result.body.data[0].pickupBranchName).toBeTruthy();
    expect(result.body.data[0].tenantId).toBeUndefined();
    expect(result.body.data[0].memberId).toBeUndefined();
  });

  it('filters all lifecycle statuses and shows reason/time in detail', async () => {
    const statuses = ['PENDING_PICKUP', 'DELIVERED', 'REJECTED', 'CANCELLED', 'EXPIRED'];
    const orders = [];
    for (const status of statuses) {
      const order = await create(member);
      orders.push(order);
      if (status !== 'PENDING_PICKUP') await ctx.tx(() => sql.exec('UPDATE redemptions SET status=$2,reason=$3,decided_at=now() WHERE id=$1', [order.id, status, 'Test result']));
    }
    for (const status of statuses) {
      const response = await ctx.api.get(base).query({ status }).set(bearer(member.token));
      expect(response.status).toBe(200);
      expect(response.body.meta.total).toBe(1);
      expect(response.body.data[0].status).toBe(status);
    }
    const detail = await ctx.api.get(`${base}/${orders[2].id}`).set(bearer(member.token));
    expect(detail.body.data).toMatchObject({ status: 'REJECTED', reason: 'Test result' });
    expect(detail.body.data.decidedAt).toBeTruthy();
  });

  it('paginates in deterministic requestedAt/id descending order', async () => {
    const first = await create(member);
    const second = await create(member);
    await ctx.tx(() => sql.exec('UPDATE redemptions SET requested_at=$2 WHERE id=$1', [first.id, new Date('2020-01-01')]));
    const result = await ctx.api.get(base).query({ page: 2, limit: 1 }).set(bearer(member.token));
    expect(result.body.meta).toMatchObject({ page: 2, limit: 1, total: 2, totalPages: 2 });
    expect(result.body.data[0].id).toBe(first.id);
    expect(result.body.data[0].id).not.toBe(second.id);
  });

  it('rejects invalid queries, unauthorized roles and other members order IDs', async () => {
    const order = await create(member);
    expect((await ctx.api.get(base)).status).toBe(401);
    const staff = await createStaff({ role: 'RECEPTIONIST', fullName: 'Reception', phone: nextPhone() });
    const staffToken = (await login(ctx.api, staff.phone)).token;
    expect((await ctx.api.get(base).set(bearer(staffToken))).status).toBe(403);
    expect((await ctx.api.get(`${base}/${order.id}`).set(bearer(other.token))).status).toBe(404);
    expect((await ctx.api.get(`${base}/${randomUUID()}`).set(bearer(member.token))).status).toBe(404);
    expect((await ctx.api.get(`${base}/bad-id`).set(bearer(member.token))).status).toBe(400);
    for (const query of [{ status: 'READY' }, { page: 0 }, { limit: 101 }, { memberId: other.userId }]) {
      expect((await ctx.api.get(base).query(query).set(bearer(member.token))).status).toBe(400);
    }
  });

  it('does not disclose another tenant order even when its ID is known', async () => {
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign tenant')`, [tenant, tenant]);
    const [foreign] = await ownerQuery<{ id: string }>(`INSERT INTO redemptions
      (tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key)
      VALUES ($1,$2,$3,$4,$5,100,$6) RETURNING id`, [tenant, randomUUID(), member.userId, rewardId, branchId, randomUUID()]);
    expect((await ctx.api.get(`${base}/${foreign.id}`).set(bearer(member.token))).status).toBe(404);
    const result = await ctx.api.get(base).set(bearer(member.token));
    expect(result.body.data).toHaveLength(0);
  });
});
