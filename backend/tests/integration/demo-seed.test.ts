import { beforeAll, describe, expect, it } from 'vitest';
import { seedDemoData, DEMO_PASSWORD } from '../../src/seeds/demo-data';
import type { Container } from '../../src/container';
import { bearer, bootTestApp, login } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('demo seed', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await bootTestApp();
  });

  it('creates one account per role and learners on different ranks, and is idempotent', async () => {
    const container = { services: ctx.services } as Container;
    const first = await seedDemoData(ctx.tenantId, container);
    expect(first.created).toHaveLength(8);
    expect((await seedDemoData(ctx.tenantId, container)).created).toHaveLength(0);

    const admin = await login(ctx.api, '0900000001', DEMO_PASSWORD);
    expect(admin.user.appRole).toBe('admin');
    const coach = await login(ctx.api, '0900000003', DEMO_PASSWORD);
    expect(coach.user.appRole).toBe('coach');
    const reception = await login(ctx.api, '0900000004', DEMO_PASSWORD);
    expect(reception.user.appRole).toBe('reception');

    const active = await login(ctx.api, '0911000002', DEMO_PASSWORD);
    const rank = await ctx.api.get('/api/v1/me/rank').set(bearer(active.token));
    expect(rank.body.data.current.rankOrder).toBe(2); // 620 DP, 45 days: rank II reached
  });
});
