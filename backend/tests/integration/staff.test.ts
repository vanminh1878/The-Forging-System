import { beforeAll, describe, expect, it } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('staff provisioning and first-use credentials', () => {
  let ctx: TestContext;
  let adminToken: string;
  let branchId: string;
  let otherBranchId: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Staff Administrator', phone: nextPhone() });
    adminToken = (await login(ctx.api, admin.phone)).token;
    const branches = await ctx.tx(() => sql.many<{ id: string }>('SELECT id FROM branches ORDER BY code'));
    [branchId, otherBranchId] = branches.map((branch) => branch.id);
  });

  async function provision(role = 'COACH') {
    const phone = nextPhone();
    const result = await ctx.api.post('/api/v1/admin/staff').set(bearer(adminToken))
      .send({ fullName: 'Coach Searchable', phone, role, branchId });
    expect(result.status).toBe(201);
    return { ...result.body.data, phone };
  }

  it('creates staff without a member profile and exposes credentials only once', async () => {
    const result = await provision();
    expect(result.staff.roles).toEqual(['COACH']);
    expect(result.staff.mustChangePassword).toBe(true);
    expect(result.temporaryPassword.length).toBeGreaterThanOrEqual(8);
    expect(result.staff.passwordHash).toBeUndefined();
    const members = await ctx.tx(() => sql.many('SELECT user_id FROM members WHERE user_id=$1', [result.staff.id]));
    expect(members).toHaveLength(0);
    const detail = await ctx.api.get(`/api/v1/admin/staff/${result.staff.id}`).set(bearer(adminToken));
    expect(detail.status).toBe(200);
    expect(detail.body.data.temporaryPassword).toBeUndefined();
    const audits = await ctx.tx(() => sql.many('SELECT after_data FROM audit_logs WHERE entity_id=$1', [result.staff.id]));
    expect(JSON.stringify(audits)).not.toContain(result.temporaryPassword);
  });

  it('searches and filters staff with pagination, without listing members', async () => {
    await provision('RECEPTIONIST');
    await registerMember(ctx.api, { fullName: 'Coach Searchable Learner' });
    const result = await ctx.api.get('/api/v1/admin/staff').set(bearer(adminToken))
      .query({ q: 'searchable', role: 'RECEPTIONIST', branchId, status: 'ACTIVE', page: 1, limit: 1 });
    expect(result.status).toBe(200);
    expect(result.body.data).toHaveLength(1);
    expect(result.body.data[0].roles).toEqual(['RECEPTIONIST']);
    expect(result.body.data[0].passwordHash).toBeUndefined();
    expect(result.body.meta.total).toBeGreaterThanOrEqual(1);
  });

  it('blocks protected APIs until the temporary password is changed and revokes old tokens', async () => {
    const result = await provision();
    const first = await login(ctx.api, result.phone, result.temporaryPassword);
    expect(first.user.mustChangePassword).toBe(true);
    const blocked = await ctx.api.get('/api/v1/members').set(bearer(first.token));
    expect(blocked.status).toBe(403);
    expect(blocked.body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
    const me = await ctx.api.get('/api/v1/auth/me').set(bearer(first.token));
    expect(me.status).toBe(200);
    const wrong = await ctx.api.post('/api/v1/auth/password/change').set(bearer(first.token))
      .send({ currentPassword: 'wrong', password: 'Permanent123!', passwordConfirm: 'Permanent123!' });
    expect(wrong.status).toBe(401);
    const changed = await ctx.api.post('/api/v1/auth/password/change').set(bearer(first.token))
      .send({ currentPassword: result.temporaryPassword, password: 'Permanent123!', passwordConfirm: 'Permanent123!' });
    expect(changed.status).toBe(204);
    expect((await ctx.api.get('/api/v1/auth/me').set(bearer(first.token))).status).toBe(401);
    expect((await ctx.api.post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken })).status).toBe(401);
    const permanent = await login(ctx.api, result.phone, 'Permanent123!');
    expect(permanent.user.mustChangePassword).toBe(false);
    expect((await ctx.api.get('/api/v1/members').set(bearer(permanent.token))).status).toBe(200);
  });

  it('changes role and branch with grant/revoke history and invalidates prior sessions', async () => {
    const result = await provision();
    const first = await login(ctx.api, result.phone, result.temporaryPassword);
    const updated = await ctx.api.patch(`/api/v1/admin/staff/${result.staff.id}`).set(bearer(adminToken))
      .send({ role: 'RECEPTIONIST', branchId: otherBranchId, reason: 'Chuyển bộ phận' });
    expect(updated.status).toBe(200);
    expect(updated.body.data.roles).toEqual(['RECEPTIONIST']);
    expect(updated.body.data.branchId).toBe(otherBranchId);
    expect((await ctx.api.get('/api/v1/auth/me').set(bearer(first.token))).status).toBe(401);
    const rows = await ctx.tx(() => sql.many<{ roleCode: string; revokedAt: Date | null }>('SELECT role_code, revoked_at FROM user_roles WHERE user_id=$1', [result.staff.id]));
    expect(rows.find((row) => row.roleCode === 'COACH')?.revokedAt).not.toBeNull();
  });

  it('disables accounts immediately and resets staff credentials to temporary passwords', async () => {
    const result = await provision();
    const first = await login(ctx.api, result.phone, result.temporaryPassword);
    const reset = await ctx.api.post(`/api/v1/admin/staff/${result.staff.id}/reset-password`).set(bearer(adminToken))
      .send({ reason: 'Nhân sự quên mật khẩu' });
    expect(reset.status).toBe(200);
    expect(reset.body.data.mustChangePassword).toBe(true);
    expect((await ctx.api.get('/api/v1/auth/me').set(bearer(first.token))).status).toBe(401);
    const next = await login(ctx.api, result.phone, reset.body.data.temporaryPassword);
    const disabled = await ctx.api.post(`/api/v1/admin/staff/${result.staff.id}/status`).set(bearer(adminToken))
      .send({ status: 'DISABLED', reason: 'Nghỉ việc' });
    expect(disabled.status).toBe(200);
    expect((await ctx.api.get('/api/v1/auth/me').set(bearer(next.token))).status).toBe(403);
    expect((await ctx.api.post('/api/v1/auth/login').send({ identifier: result.phone, password: reset.body.data.temporaryPassword })).status).toBe(403);
  });

  it('validates contacts and branches and denies non-admin access and super-admin escalation', async () => {
    const result = await provision();
    const duplicate = await ctx.api.post('/api/v1/admin/staff').set(bearer(adminToken))
      .send({ fullName: 'Duplicate Staff', phone: result.phone, role: 'COACH', branchId });
    expect(duplicate.status).toBe(409);
    expect((await ctx.api.post('/api/v1/admin/staff').set(bearer(adminToken))
      .send({ fullName: 'Bad branch', phone: nextPhone(), role: 'COACH', branchId: '00000000-0000-4000-8000-000000000001' })).status).toBe(400);
    expect((await ctx.api.post('/api/v1/admin/staff').set(bearer(adminToken))
      .send({ fullName: 'Escalation', phone: nextPhone(), role: 'SUPER_ADMIN', branchId })).status).toBe(403);
    const learner = await registerMember(ctx.api);
    expect((await ctx.api.get('/api/v1/admin/staff').set(bearer(learner.token))).status).toBe(403);
    expect((await ctx.api.get('/api/v1/admin/staff')).status).toBe(401);
    expect((await ctx.api.patch(`/api/v1/admin/staff/${learner.userId}`).set(bearer(adminToken))
      .send({ role: 'COACH', reason: 'Not a staff account' })).status).toBe(404);
  });

  it('prevents disabling or demoting the last active Super Admin', async () => {
    const seeded = await createStaff({ role: 'ADMIN', fullName: 'Super Admin', phone: nextPhone() });
    await ownerQuery(`UPDATE user_roles SET role_code='SUPER_ADMIN' WHERE user_id=$1`, [seeded.userId]);
    const superAdmin = await login(ctx.api, seeded.phone);
    expect((await ctx.api.post(`/api/v1/admin/staff/${seeded.userId}/status`).set(bearer(superAdmin.token))
      .send({ status: 'DISABLED', reason: 'Last super admin' })).status).toBe(409);
    expect((await ctx.api.patch(`/api/v1/admin/staff/${seeded.userId}`).set(bearer(superAdmin.token))
      .send({ role: 'COACH', reason: 'Last super admin' })).status).toBe(409);
  });
});
