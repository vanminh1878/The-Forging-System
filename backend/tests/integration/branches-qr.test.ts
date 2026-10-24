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

describe('branches: check-in QR', () => {
  let ctx: TestContext;
  let admin: string;
  let desk: string;
  let coach: string;
  let member: string;
  let q1: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    member = (await registerMember(ctx.api)).token;
    admin = (
      await login(
        ctx.api,
        (await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() })).phone,
      )
    ).token;
    desk = (
      await login(
        ctx.api,
        (await createStaff({ role: 'RECEPTIONIST', fullName: 'Desk', phone: nextPhone() })).phone,
      )
    ).token;
    coach = (
      await login(
        ctx.api,
        (await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() })).phone,
      )
    ).token;
    q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
  });

  const getQr = (token: string) => ctx.api.get(`/api/v1/branches/${q1}/qr`).set(bearer(token));
  const rotate = (token: string, body: object = {}) =>
    ctx.api.post(`/api/v1/admin/branches/${q1}/qr/rotate`).set(bearer(token)).send(body);

  it('GET qr is for front desk and admin only', async () => {
    expect((await ctx.api.get(`/api/v1/branches/${q1}/qr`)).status).toBe(401);
    expect((await getQr(member)).status).toBe(403);
    expect((await getQr(coach)).status).toBe(403);
    const res = await getQr(desk);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ branchId: q1, code: 'Q1', qrVersion: '1', payload: 'HVP|Q1|1' });
    expect(
      (await ctx.api.get('/api/v1/branches/00000000-0000-0000-0000-000000000000/qr').set(bearer(desk)))
        .status,
    ).toBe(404);
  });

  it('rotate is admin-only and bumps the version, audited', async () => {
    expect((await rotate(desk)).status).toBe(403);
    const first = await rotate(admin);
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ qrVersion: '2', payload: 'HVP|Q1|2' });
    const second = await rotate(admin, { reason: 'Mất bảng QR' });
    expect(second.body.data.qrVersion).toBe('3');
    expect((await getQr(desk)).body.data.qrVersion).toBe('3');
    const logs = await ownerQuery<{ reason: string; after_data: { qrVersion: string } }>(
      `SELECT reason, after_data FROM audit_logs WHERE action = 'BRANCH_QR_UPDATED' ORDER BY created_at`,
    );
    expect(logs.map((l) => [l.reason, l.after_data.qrVersion])).toEqual([
      ['Cập nhật QR check-in', '2'],
      ['Mất bảng QR', '3'],
    ]);
    const detail = await ctx.api.get(`/api/v1/branches/${q1}`).set(bearer(coach));
    expect(detail.body.data.qrVersion).toBe('3');
  });

  it('handles non-numeric versions, fills an empty prefix and validates', async () => {
    await ownerQuery(`UPDATE branches SET qr_version = 'abc', qr_prefix = NULL WHERE id = $1`, [q1]);
    expect((await rotate(admin)).body.data.qrVersion).toBe('2');
    expect(
      (await ownerQuery<{ qr_prefix: string }>(`SELECT qr_prefix FROM branches WHERE id = $1`, [q1]))[0]
        .qr_prefix,
    ).toBe('HVP-Q1');
    expect((await rotate(admin, { reason: 'ab' })).status).toBe(400);
    expect(
      (
        await ctx.api
          .post('/api/v1/admin/branches/00000000-0000-0000-0000-000000000000/qr/rotate')
          .set(bearer(admin))
          .send({})
      ).status,
    ).toBe(404);
  });
});
