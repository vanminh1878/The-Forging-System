import { beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, DEFAULT_PASSWORD, login, nextPhone, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('auth', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await bootTestApp();
  });

  it('registers a learner, initialises rank I and logs in with phone or email', async () => {
    const phone = nextPhone();
    const reg = await ctx.api.post('/api/v1/auth/register').send({ fullName: 'Nguyễn Văn A', phone, email: 'a@example.com', password: DEFAULT_PASSWORD });
    expect(reg.status).toBe(201);
    expect(reg.body.data.user.appRole).toBe('student');

    const byPhone = await login(ctx.api, phone);
    const byEmail = await login(ctx.api, 'A@Example.com');
    expect(byPhone.user.id).toBe(byEmail.user.id);

    const rank = await ctx.api.get('/api/v1/me/rank').set(bearer(byPhone.token));
    expect(rank.status).toBe(200);
    expect(rank.body.data.current.rankOrder).toBe(1);
    expect(rank.body.data.next.rankOrder).toBe(2);
  });

  it('allows only one account per phone number (shared by every branch)', async () => {
    const phone = nextPhone();
    await registerMember(ctx.api, { phone });
    const again = await ctx.api.post('/api/v1/auth/register').send({ fullName: 'Người Trùng', phone, password: DEFAULT_PASSWORD });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('PHONE_TAKEN');
  });

  it('rejects wrong credentials and weak passwords', async () => {
    const { phone } = await registerMember(ctx.api);
    const bad = await ctx.api.post('/api/v1/auth/login').send({ identifier: phone, password: 'wrong-password' });
    expect(bad.status).toBe(401);
    const weak = await ctx.api.post('/api/v1/auth/register').send({ fullName: 'Yếu', phone: nextPhone(), password: 'abcdefgh' });
    expect(weak.status).toBe(400);
  });

  it('rotates refresh tokens (single use)', async () => {
    const { phone } = await registerMember(ctx.api);
    const first = await login(ctx.api, phone);
    const rotated = await ctx.api.post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });
    expect(rotated.status).toBe(200);
    const replay = await ctx.api.post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });
    expect(replay.status).toBe(401);
  });

  it('resets a password with phone + PIN', async () => {
    const { phone } = await registerMember(ctx.api);
    const forgot = await ctx.api.post('/api/v1/auth/password/forgot').send({ phone });
    expect(forgot.status).toBe(200);
    const { requestId, devPin } = forgot.body.data;
    expect(devPin).toHaveLength(6);

    const wrong = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: '000000' });
    expect(wrong.status).toBe(400);
    const verified = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: devPin });
    expect(verified.status).toBe(200);

    const reset = await ctx.api
      .post('/api/v1/auth/password/reset')
      .send({ requestId, resetToken: verified.body.data.resetToken, password: 'NewPass123', passwordConfirm: 'NewPass123' });
    expect(reset.status).toBe(204);
    await login(ctx.api, phone, 'NewPass123');
  });

  it('blocks INACTIVE members from signing in but lets FROZEN members in', async () => {
    const { phone, userId } = await registerMember(ctx.api);
    await ctx.tx(() => ctx.services.members.changeStatus({ memberId: userId, status: 'FROZEN', reason: 'test', by: null, via: 'BATCH' }));
    await login(ctx.api, phone);
    await ctx.tx(async () => {
      await ctx.services.members.changeStatus({ memberId: userId, status: 'INACTIVE', reason: 'test', by: null, via: 'BATCH' });
    });
    const res = await ctx.api.post('/api/v1/auth/login').send({ identifier: phone, password: DEFAULT_PASSWORD });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_INACTIVE');
  });
});
