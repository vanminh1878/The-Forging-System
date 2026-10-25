import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-03 member redemption history and status', () => {
  let ctx: TestContext;
  let firstMember: { userId: string; token: string };
  let secondMember: { userId: string; token: string };
  let rewardId: string;
  let branchId: string;

  beforeAll(async () => { ctx = await bootTestApp(); });
  beforeEach(async () => {
    firstMember = await registerMember(ctx.api);
    secondMember = await registerMember(ctx.api);
    await ctx.tx(async () => {
      await ctx.services.points.award({ memberId: firstMember.userId, source: 'OPENING', marks: 500, note: 'Wallet fixture' });
      await ctx.services.points.award({ memberId: secondMember.userId, source: 'OPENING', marks: 300, note: 'Wallet fixture' });
      branchId = (await sql.scalar<string>('SELECT id FROM branches LIMIT 1'))!;
      rewardId = (await sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
        VALUES ($1,$2,'History gift',100,20) RETURNING id`, [ctx.tenantId, randomUUID()]))!;
    });
  });

  async function create(member: { userId: string; token: string }) {
    const result = await ctx.api.post('/api/v1/armory/redemptions').set(bearer(member.token))
      .send({ rewardId, pickupBranchId: branchId });
    expect(result.status).toBe(201);
    return result.body.data.redemption as { id: string; status: string };
  }

  it('lists only the authenticated member orders with reward and pickup snapshot data', async () => {
    const order = await create(firstMember);
    await create(secondMember);
    const response = await ctx.api.get('/api/v1/me/armory/redemptions?page=1&limit=10').set(bearer(firstMember.token));
    expect(response.status).toBe(200);
    expect(response.body.meta).toMatchObject({ page: 1, limit: 10, total: 1 });
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0]).toMatchObject({ id: order.id, rewardId, rewardName: 'History gift', status: 'PENDING_PICKUP', marksCost: 100 });
    expect(response.body.data[0]).toHaveProperty('pickupBranchName');
    expect(response.body.data[0]).not.toHaveProperty('memberId');
    expect(response.body.data[0]).not.toHaveProperty('tenantId');
  });

  it('filters status and reflects each order lifecycle status', async () => {
    const pending = await create(firstMember);
    const delivered = await create(firstMember);
    const rejected = await create(firstMember);
    await ctx.tx(async () => {
      await sql.exec(`UPDATE redemptions SET status='DELIVERED',decided_at=now() WHERE id=$1`, [delivered.id]);
      await sql.exec(`UPDATE redemptions SET status='REJECTED',reason='Out of stock',decided_at=now() WHERE id=$1`, [rejected.id]);
    });
    const all = await ctx.api.get('/api/v1/me/armory/redemptions').set(bearer(firstMember.token));
    expect(all.body.meta.total).toBe(3);
    expect(all.body.data.map((entry: { id: string }) => entry.id)).toContain(pending.id);
    for (const status of ['PENDING_PICKUP', 'DELIVERED', 'REJECTED']) {
      const filtered = await ctx.api.get('/api/v1/me/armory/redemptions').query({ status }).set(bearer(firstMember.token));
      expect(filtered.status).toBe(200);
      expect(filtered.body.meta.total).toBe(1);
      expect(filtered.body.data[0].status).toBe(status);
    }
    const detail = await ctx.api.get(`/api/v1/me/armory/redemptions/${rejected.id}`).set(bearer(firstMember.token));
    expect(detail.body.data).toMatchObject({ status: 'REJECTED', reason: 'Out of stock', rewardSku: expect.any(String) });
    expect(detail.body.data.decidedAt).toBeTruthy();
  });

  it('paginates newest first with deterministic order', async () => {
    await create(firstMember);
    await create(firstMember);
    const page = await ctx.api.get('/api/v1/me/armory/redemptions?page=2&limit=1').set(bearer(firstMember.token));
    expect(page.status).toBe(200);
    expect(page.body.meta).toMatchObject({ page: 2, limit: 1, total: 2, totalPages: 2 });
    expect(page.body.data).toHaveLength(1);
  });

  it('returns not found for another member redemption and invalid IDs', async () => {
    const order = await create(firstMember);
    expect((await ctx.api.get(`/api/v1/me/armory/redemptions/${order.id}`).set(bearer(secondMember.token))).status).toBe(404);
    expect((await ctx.api.get(`/api/v1/me/armory/redemptions/${randomUUID()}`).set(bearer(firstMember.token))).status).toBe(404);
    expect((await ctx.api.get('/api/v1/me/armory/redemptions/not-uuid').set(bearer(firstMember.token))).status).toBe(400);
  });

  it('rejects unauthenticated, staff and invalid filter requests', async () => {
    expect((await ctx.api.get('/api/v1/me/armory/redemptions')).status).toBe(401);
    const staff = await createStaff({ role: 'RECEPTIONIST', fullName: 'History Staff', phone: nextPhone() });
    const session = await login(ctx.api, staff.phone);
    expect((await ctx.api.get('/api/v1/me/armory/redemptions').set(bearer(session.token))).status).toBe(403);
    for (const query of [{ status: 'READY' }, { page: 0 }, { limit: 101 }, { q: 'unexpected' }]) {
      expect((await ctx.api.get('/api/v1/me/armory/redemptions').query(query).set(bearer(firstMember.token))).status).toBe(400);
    }
  });
});
