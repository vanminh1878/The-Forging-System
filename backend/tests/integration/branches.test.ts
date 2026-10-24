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

describe('branches: list and detail', () => {
  let ctx: TestContext;
  let member: string;
  let admin: string;
  let coach: string;
  let q1: string;
  let inactiveId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    member = (await registerMember(ctx.api)).token;
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    admin = (await login(ctx.api, a.phone)).token;
    const c = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    coach = (await login(ctx.api, c.phone)).token;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    await ownerQuery(
      `UPDATE branches SET opening_hours = '06:00 – 21:30', latitude = 10.77, longitude = 106.69 WHERE id = $1`,
      [q1],
    );
    inactiveId = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO branches (tenant_id, code, name, is_active) SELECT id, 'OLD', 'A Old Branch', false FROM tenants WHERE code = 'hvp' RETURNING id`,
      )
    )[0].id;
  });

  it('requires authentication', async () => {
    expect((await ctx.api.get('/api/v1/branches')).status).toBe(401);
  });

  it('lists active branches ordered by name, keeping the mobile keys', async () => {
    const res = await ctx.api.get('/api/v1/branches').set(bearer(member));
    expect(res.status).toBe(200);
    expect(res.body.data.map((b: { code: string }) => b.code)).toEqual(['Q7', 'Q1']);
    expect(res.body.data.find((b: { code: string }) => b.code === 'Q1')).toMatchObject({
      id: q1,
      code: 'Q1',
      name: 'HVP Boxing - The Corner',
      address: null,
      openingHours: '06:00 – 21:30',
      latitude: 10.77,
      longitude: 106.69,
      geofenceRadiusM: 100,
      isActive: true,
    });
    expect(res.body.data[0]).not.toHaveProperty('qrVersion');
  });

  it('includeInactive is honoured for admins only', async () => {
    const asAdmin = await ctx.api.get('/api/v1/branches?includeInactive=true').set(bearer(admin));
    expect(asAdmin.body.data.map((b: { code: string }) => b.code)).toEqual(['OLD', 'Q7', 'Q1']);
    expect(asAdmin.body.data[0]).toHaveProperty('qrVersion');
    const asCoach = await ctx.api.get('/api/v1/branches?includeInactive=true').set(bearer(coach));
    expect(asCoach.body.data).toHaveLength(2);
    expect((await ctx.api.get('/api/v1/branches?includeInactive=yes').set(bearer(admin))).status).toBe(400);
  });

  it('detail: 404 for unknown, hidden inactive for members, qrVersion for staff', async () => {
    const missing = await ctx.api
      .get('/api/v1/branches/00000000-0000-0000-0000-000000000000')
      .set(bearer(member));
    expect(missing.status).toBe(404);
    expect((await ctx.api.get('/api/v1/branches/not-a-uuid').set(bearer(member))).status).toBe(400);
    expect((await ctx.api.get(`/api/v1/branches/${inactiveId}`).set(bearer(member))).status).toBe(404);

    const m = await ctx.api.get(`/api/v1/branches/${q1}`).set(bearer(member));
    expect(m.status).toBe(200);
    expect(m.body.data).not.toHaveProperty('qrVersion');
    const s = await ctx.api.get(`/api/v1/branches/${inactiveId}`).set(bearer(coach));
    expect(s.status).toBe(200);
    expect(s.body.data).toMatchObject({ code: 'OLD', isActive: false, qrVersion: null });
  });
});
