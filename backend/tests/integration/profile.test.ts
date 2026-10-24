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

describe('profile (AUTH-11)', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await bootTestApp();
  });
  const patch = (token: string, body: object) =>
    ctx.api.patch('/api/v1/me/profile').set(bearer(token)).send(body);
  const row = async (id: string) =>
    (
      await ownerQuery<Record<string, unknown>>(
        `SELECT u.*, m.home_branch_id AS mh FROM users u JOIN members m ON m.user_id = u.id WHERE u.id = $1`,
        [id],
      )
    )[0];

  it('views and edits the profile, writing an audit row', async () => {
    const { token, userId } = await registerMember(ctx.api, { email: 'edit@example.com' });
    const res = await patch(token, { fullName: 'Tên Mới', dateOfBirth: '1990-05-01', gender: 'MALE' });
    expect(res.status).toBe(200);
    expect(res.body.data.fullName).toBe('Tên Mới');
    expect((await ctx.api.get('/api/v1/me/profile').set(bearer(token))).body.data.gender).toBe('MALE');
    const audit = await ownerQuery(
      `SELECT * FROM audit_logs WHERE action = 'PROFILE_UPDATED' AND entity_id = $1`,
      [userId],
    );
    expect(audit).toHaveLength(1);
  });

  it('explicit null clears dateOfBirth and gender', async () => {
    const { token } = await registerMember(ctx.api);
    await patch(token, { dateOfBirth: '1990-05-01', gender: 'FEMALE' });
    const res = await patch(token, { dateOfBirth: null, gender: null });
    expect(res.status).toBe(200);
    expect(res.body.data.dateOfBirth).toBeNull();
    expect(res.body.data.gender).toBeNull();
  });

  it('rejects taken phone/email and allows re-sending own values', async () => {
    const other = await registerMember(ctx.api, { email: 'taken@example.com' });
    const me = await registerMember(ctx.api, { email: 'mine@example.com' });
    const p = await patch(me.token, { phone: other.phone });
    expect([p.status, p.body.error.code]).toEqual([409, 'PHONE_TAKEN']);
    const e = await patch(me.token, { email: 'TAKEN@example.com' });
    expect([e.status, e.body.error.code]).toEqual([409, 'EMAIL_TAKEN']);
    expect((await patch(me.token, { phone: me.phone, email: 'mine@example.com' })).status).toBe(200);
  });

  it('rejects clearing both contacts', async () => {
    const { token } = await registerMember(ctx.api, { email: 'both@example.com' });
    const res = await patch(token, { phone: null, email: null });
    expect([res.status, res.body.error.code]).toEqual([400, 'CONTACT_REQUIRED']);
    expect((await patch(token, { email: null })).status).toBe(200);
  });

  it('resets verification stamps only when the contact changes', async () => {
    const { token, userId, phone } = await registerMember(ctx.api, { email: 'ver@example.com' });
    await ownerQuery(`UPDATE users SET phone_verified_at = now(), email_verified_at = now() WHERE id = $1`, [
      userId,
    ]);
    await patch(token, { phone, fullName: 'Same Phone' });
    let r = await row(userId);
    expect(r.phone_verified_at).not.toBeNull();
    await patch(token, { phone: nextPhone() });
    r = await row(userId);
    expect(r.phone_verified_at).toBeNull();
    expect(r.email_verified_at).not.toBeNull();
    await patch(token, { email: 'ver2@example.com' });
    expect((await row(userId)).email_verified_at).toBeNull();
  });

  it('validates avatarUrl against the uploads base', async () => {
    const { token } = await registerMember(ctx.api);
    const bad = await patch(token, { avatarUrl: 'https://evil.example.com/a.jpg' });
    expect([bad.status, bad.body.error.code]).toEqual([400, 'INVALID_AVATAR_URL']);
    const { env } = await import('../../src/config/env');
    const url = `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/hvp/avatars/x/2026-10/a.jpg`;
    const ok = await patch(token, { avatarUrl: url });
    expect(ok.body.data.avatarUrl).toBe(url);
    expect((await patch(token, { avatarUrl: null })).body.data.avatarUrl).toBeNull();
  });

  it('sets homeBranchId only to an active branch', async () => {
    const { token, userId } = await registerMember(ctx.api);
    const [q1, q7] = await ownerQuery<{ id: string }>(`SELECT id FROM branches ORDER BY code`);
    const ok = await patch(token, { homeBranchId: q1.id });
    expect(ok.body.data.homeBranchId).toBe(q1.id);
    expect((await row(userId)).mh).toBe(q1.id);
    await ownerQuery(`UPDATE branches SET is_active = false WHERE id = $1`, [q7.id]);
    const inactive = await patch(token, { homeBranchId: q7.id });
    expect([inactive.status, inactive.body.error.code]).toEqual([400, 'INVALID_BRANCH']);
    const missing = await patch(token, { homeBranchId: '00000000-0000-4000-8000-000000000000' });
    expect([missing.status, missing.body.error.code]).toEqual([400, 'INVALID_BRANCH']);
    await ownerQuery(`UPDATE branches SET is_active = true WHERE id = $1`, [q7.id]);
    expect((await patch(token, { homeBranchId: null })).body.data.homeBranchId).toBeNull();
  });

  it('requires auth and the member role', async () => {
    expect((await ctx.api.get('/api/v1/me/profile')).status).toBe(401);
    const staff = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    const { token } = await login(ctx.api, staff.phone);
    expect((await ctx.api.get('/api/v1/me/profile').set(bearer(token))).status).toBe(403);
    const { token: t } = await registerMember(ctx.api);
    expect((await patch(t, { gender: 'X' })).status).toBe(400);
  });
});
