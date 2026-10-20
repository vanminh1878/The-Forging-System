import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('ARM-01 learner catalogue APIs', () => {
  let ctx: TestContext;
  let token: string;
  const now = new Date('2026-10-15T12:00:00Z');

  beforeAll(async () => {
    ctx = await bootTestApp();
    token = (await registerMember(ctx.api)).token;
    setClock(fixedClock(now));
    await ctx.tx(async () => {
      await sql.exec(`INSERT INTO rewards (tenant_id,sku,name,tier_code,marks_cost,stock,is_active,sale_starts_at,sale_ends_at)
        VALUES ($1,'WATER','HVP Water','FIELD_SUPPLIES',80,3,true,NULL,NULL),
        ($1,'EMPTY','HVP Sold Out','FIELD_SUPPLIES',90,0,true,NULL,NULL),
        ($1,'WRAPS','HVP Wraps','TRAINING_GEAR',220,4,true,NULL,NULL),
        ($1,'DISABLED','Hidden disabled','FIELD_SUPPLIES',50,2,false,NULL,NULL),
        ($1,'FUTURE','Hidden future','FIELD_SUPPLIES',60,2,true,$2::timestamptz + interval '1 day',NULL),
        ($1,'ENDED','Hidden ended','FIELD_SUPPLIES',60,2,true,NULL,$2),
        ($1,'STARTED','Visible starting now','FIELD_SUPPLIES',100,1,true,$2,NULL),
        ($1,'UNGROUPED','No tier',NULL,10,1,true,NULL,NULL)`, [ctx.tenantId, now]);
    });
  });
  afterAll(resetClock);

  it('lists tiers in the configured order, including empty tiers', async () => {
    const result = await ctx.api.get('/api/v1/armory/tiers').set(bearer(token));
    expect(result.status).toBe(200);
    expect(result.body.data.map((tier: { code: string }) => tier.code)).toEqual(['FIELD_SUPPLIES', 'TRAINING_GEAR', 'FIGHTER_EQUIPMENT', 'BLACK_VAULT']);
    expect(result.body.data[0]).toHaveProperty('minMarks');
    expect(result.body.data[0].tenantId).toBeUndefined();
  });

  it('returns only active on-sale rewards, ordered by tier and price, with stock and conditions', async () => {
    const result = await ctx.api.get('/api/v1/armory/rewards').set(bearer(token));
    expect(result.status).toBe(200);
    expect(result.body.data.map((reward: { sku: string }) => reward.sku)).toEqual(['WATER', 'EMPTY', 'STARTED', 'WRAPS', 'UNGROUPED']);
    expect(result.body.data.find((reward: { sku: string }) => reward.sku === 'EMPTY')).toMatchObject({ stock: 0, inStock: false, tierName: 'FIELD SUPPLIES' });
    expect(result.body.data[0]).toHaveProperty('perMemberLimit');
    expect(result.body.data[0]).toHaveProperty('minRankId');
    expect(result.body.data[0].tenantId).toBeUndefined();
  });

  it('filters by tier and literal name/SKU, paginates, and handles unknown tiers', async () => {
    const result = await ctx.api.get('/api/v1/armory/rewards?tierCode=FIELD_SUPPLIES&page=2&limit=1').set(bearer(token));
    expect(result.status).toBe(200);
    expect(result.body.meta).toMatchObject({ page: 2, limit: 1, total: 3, totalPages: 3 });
    expect(result.body.data[0].sku).toBe('EMPTY');
    const search = await ctx.api.get('/api/v1/armory/rewards?q=wrap').set(bearer(token));
    expect(search.body.data).toHaveLength(1);
    expect(search.body.data[0].sku).toBe('WRAPS');
    const literal = await ctx.api.get('/api/v1/armory/rewards').query({ q: '%' }).set(bearer(token));
    expect(literal.body.data).toHaveLength(0);
    expect((await ctx.api.get('/api/v1/armory/rewards?tierCode=UNKNOWN').set(bearer(token))).body.data).toHaveLength(0);
    expect((await ctx.api.get('/api/v1/armory/rewards?limit=101').set(bearer(token))).status).toBe(400);
    expect((await ctx.api.get('/api/v1/armory/rewards?page=0').set(bearer(token))).status).toBe(400);
  });

  it('requires a learner token and isolates tenants', async () => {
    expect((await ctx.api.get('/api/v1/armory/rewards')).status).toBe(401);
    for (const role of ['ADMIN', 'COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await ctx.api.get('/api/v1/armory/tiers').set(bearer(session.token))).status).toBe(403);
      expect((await ctx.api.get('/api/v1/armory/rewards').set(bearer(session.token))).status).toBe(403);
    }
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign')`, [tenant, tenant]);
    await ownerQuery(`INSERT INTO reward_tiers (tenant_id,code,name,min_marks,sort_order) VALUES ($1,'PRIVATE','Foreign tier',0,0)`, [tenant]);
    await ownerQuery(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock,tier_code) VALUES ($1,'SECRET','Foreign reward',1,10,'PRIVATE')`, [tenant]);
    expect((await ctx.api.get('/api/v1/armory/rewards?q=Foreign').set(bearer(token))).body.data).toHaveLength(0);
    expect((await ctx.api.get('/api/v1/armory/tiers').set(bearer(token))).body.data).toHaveLength(4);
  });
});
