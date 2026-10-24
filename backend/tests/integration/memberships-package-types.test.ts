import { beforeAll, describe, expect, it } from 'vitest';
import {
  bearer,
  bootTestApp,
  createStaff,
  login,
  nextPhone,
  ownerQuery,
  registerMember,
} from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('GET /package-types (MEM-01)', () => {
  let ctx: TestContext;
  let memberToken: string;
  let adminToken: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    memberToken = (await registerMember(ctx.api)).token;
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminToken = (await login(ctx.api, admin.phone)).token;
    await ownerQuery(`UPDATE package_types SET is_active = false WHERE code = 'GT_12M'`);
  });

  it('rejects anonymous callers', async () => {
    expect((await ctx.api.get('/api/v1/package-types')).status).toBe(401);
  });

  it('lists active types in sort order with price for a member', async () => {
    const res = await ctx.api.get('/api/v1/package-types').set(bearer(memberToken));
    expect(res.status).toBe(200);
    const codes = res.body.data.map((p: { code: string }) => p.code);
    expect(codes[0]).toBe('BOOK_1');
    expect(codes).not.toContain('GT_12M');
    expect(res.body.data[0]).toMatchObject({
      durationDays: 84,
      totalSessions: 36,
      sessionsPerWeek: 3,
      isTrial: false,
      priceVnd: 8_900_000,
    });
    expect(res.body.data[0]).not.toHaveProperty('isActive');
  });

  it('ignores includeInactive for members', async () => {
    const res = await ctx.api.get('/api/v1/package-types?includeInactive=true').set(bearer(memberToken));
    expect(res.body.data.map((p: { code: string }) => p.code)).not.toContain('GT_12M');
  });

  it('lets admins include inactive types', async () => {
    const res = await ctx.api.get('/api/v1/package-types?includeInactive=true').set(bearer(adminToken));
    const gt12 = res.body.data.find((p: { code: string }) => p.code === 'GT_12M');
    expect(gt12).toMatchObject({ isActive: false });
  });

  it('validates the query', async () => {
    expect(
      (await ctx.api.get('/api/v1/package-types?includeInactive=maybe').set(bearer(adminToken))).status,
    ).toBe(400);
  });
});
