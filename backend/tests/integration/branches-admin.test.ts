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

describe('branches: admin create / edit / status', () => {
  let ctx: TestContext;
  let admin: string;
  let coach: string;
  let member: string;
  let adminId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    member = (await registerMember(ctx.api)).token;
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminId = a.userId;
    admin = (await login(ctx.api, a.phone)).token;
    const c = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    coach = (await login(ctx.api, c.phone)).token;
  });

  const post = (url: string, token: string, body: object) =>
    ctx.api.post(`/api/v1${url}`).set(bearer(token)).send(body);
  const audits = (action: string) =>
    ownerQuery<{ reason: string | null; actor_id: string }>(
      `SELECT reason, actor_id FROM audit_logs WHERE action = $1`,
      [action],
    );

  it('is admin-only', async () => {
    expect((await ctx.api.post('/api/v1/admin/branches').send({})).status).toBe(401);
    expect((await post('/admin/branches', member, { code: 'Q9', name: 'Chi nhánh 9' })).status).toBe(403);
    expect((await post('/admin/branches', coach, { code: 'Q9', name: 'Chi nhánh 9' })).status).toBe(403);
  });

  it('creates with defaults, uppercases the code and audits', async () => {
    const res = await post('/admin/branches', admin, {
      code: 'q9',
      name: 'HVP Quận 9',
      openingHours: '06:00 – 21:00',
      latitude: 10.8,
      longitude: 106.8,
    });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      code: 'Q9',
      name: 'HVP Quận 9',
      address: null,
      geofenceRadiusM: 100,
      isActive: true,
      latitude: 10.8,
    });
    expect(await audits('BRANCH_CREATED')).toHaveLength(1);
    const list = await ctx.api.get('/api/v1/branches').set(bearer(member));
    expect(list.body.data.map((b: { code: string }) => b.code)).toContain('Q9');
  });

  it('validates input and rejects duplicate codes', async () => {
    expect((await post('/admin/branches', admin, { code: 'x y', name: 'Sai mã' })).status).toBe(400);
    expect((await post('/admin/branches', admin, { code: 'Q1' })).status).toBe(400);
    expect((await post('/admin/branches', admin, { code: 'Z1', name: 'Z', latitude: 200 })).status).toBe(400);
    const dup = await post('/admin/branches', admin, { code: 'q1', name: 'Trùng' });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('BRANCH_CODE_TAKEN');
  });

  it('patches partially, clears nullable fields, keeps code unique', async () => {
    const q7 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q7'`))[0].id;
    const patch = (body: object, id = q7) =>
      ctx.api.patch(`/api/v1/admin/branches/${id}`).set(bearer(admin)).send(body);
    const ok = await patch({ address: '1 Đường A', geofenceRadiusM: 150 });
    expect(ok.status).toBe(200);
    expect(ok.body.data).toMatchObject({
      code: 'Q7',
      name: 'HVP Boxing - Riverside',
      address: '1 Đường A',
      geofenceRadiusM: 150,
    });
    expect((await patch({ address: null })).body.data.address).toBeNull();
    expect((await patch({ code: 'Q7' })).status).toBe(200); // same code is fine
    expect((await patch({ code: 'Q1' })).body.error.code).toBe('BRANCH_CODE_TAKEN');
    expect((await patch({ geofenceRadiusM: 0 })).status).toBe(400);
    expect((await patch({ name: 'XX' }, '00000000-0000-0000-0000-000000000000')).status).toBe(404);
    expect((await audits('BRANCH_UPDATED')).length).toBe(3);
    expect(
      (await ctx.api.patch(`/api/v1/admin/branches/${q7}`).set(bearer(coach)).send({ name: 'Hack' })).status,
    ).toBe(403);
  });

  it('toggles status with a mandatory reason; no-op when unchanged', async () => {
    const q7 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q7'`))[0].id;
    const url = `/admin/branches/${q7}/status`;
    expect((await post(url, admin, { isActive: false })).status).toBe(400);
    expect((await post(url, admin, { isActive: false, reason: 'ab' })).status).toBe(400);
    const off = await post(url, admin, { isActive: false, reason: 'Đóng cửa sửa chữa' });
    expect(off.status).toBe(200);
    expect(off.body.data.isActive).toBe(false);
    const again = await post(url, admin, { isActive: false, reason: 'Đóng cửa sửa chữa' });
    expect(again.status).toBe(200);
    expect(await audits('BRANCH_DEACTIVATED')).toEqual([{ reason: 'Đóng cửa sửa chữa', actor_id: adminId }]);
    const hidden = await ctx.api.get('/api/v1/branches').set(bearer(member));
    expect(hidden.body.data.map((b: { code: string }) => b.code)).not.toContain('Q7');
    await post(url, admin, { isActive: true, reason: 'Mở lại' });
    expect(await audits('BRANCH_ACTIVATED')).toHaveLength(1);
    expect(
      (
        await post('/admin/branches/00000000-0000-0000-0000-000000000000/status', admin, {
          isActive: true,
          reason: 'abc',
        })
      ).status,
    ).toBe(404);
  });
});
