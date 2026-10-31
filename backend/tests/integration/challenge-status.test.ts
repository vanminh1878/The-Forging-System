import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('CHL-02 Admin Challenge status API', () => {
  let ctx: TestContext;
  let token: string;
  const input = { title: 'Status test', challengeType: 'MONTHLY', target: 3, rewardDp: 100, rewardMarks: 40,
    startsAt: '2026-10-01T00:00:00Z', endsAt: '2026-11-01T00:00:00Z' };
  const statusPath = (id: string) => `/api/v1/admin/challenges/${id}/status`;

  beforeAll(async () => {
    ctx = await bootTestApp();
    setClock(fixedClock(new Date('2026-10-15T12:00:00Z')));
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Status Admin', phone: nextPhone() });
    token = (await login(ctx.api, admin.phone)).token;
  });
  afterAll(resetClock);

  async function create(patch: Record<string, unknown> = {}) {
    const result = await ctx.api.post('/api/v1/admin/challenges').set(bearer(token)).send({ ...input, ...patch });
    expect(result.status).toBe(201);
    return result.body.data;
  }
  const change = (id: string, enabled: boolean) => ctx.api.patch(statusPath(id)).set(bearer(token)).send({ enabled, reason: 'Admin status change' });

  it('publishes, disables and reopens with audit and unchanged reward fields', async () => {
    const row = await create();
    for (const enabled of [true, false, true]) {
      const result = await change(row.id, enabled);
      expect(result.status).toBe(200);
      expect(result.body.data).toMatchObject({ enabled, status: enabled ? 'OPEN' : 'CLOSED', rewardDp: 100, rewardMarks: 40 });
      expect(result.body.data.tenantId).toBeUndefined();
    }
    const logs = await ctx.tx(() => sql.many<{ action: string; beforeData: { status: string }; afterData: { status: string } }>(`SELECT action,before_data,after_data FROM audit_logs
      WHERE entity_id=$1 AND action IN ('CHALLENGE_ENABLED','CHALLENGE_DISABLED') ORDER BY created_at,id`, [row.id]));
    expect(logs.map((log) => log.action)).toEqual(['CHALLENGE_ENABLED', 'CHALLENGE_DISABLED', 'CHALLENGE_ENABLED']);
    expect(logs[0]).toMatchObject({ beforeData: { status: 'DRAFT' }, afterData: { status: 'OPEN' } });
  });

  it('handles duplicate and concurrent requests idempotently', async () => {
    const row = await create();
    const draftOff = await change(row.id, false);
    expect(draftOff.body.data).toMatchObject({ status: 'DRAFT', enabled: false, updatedAt: row.updatedAt });
    const results = await Promise.all([change(row.id, true), change(row.id, true)]);
    expect(results.every((result) => result.status === 200)).toBe(true);
    const repeated = await change(row.id, true);
    expect(repeated.body.data.updatedAt).toBe(results[0].body.data.updatedAt);
    await change(row.id, false).expect(200);
    const secondOff = await change(row.id, false);
    expect(secondOff.body.data).toMatchObject({ status: 'CLOSED', enabled: false });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='CHALLENGE_ENABLED'`, [row.id]))).toBe(1);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='CHALLENGE_DISABLED'`, [row.id]))).toBe(1);
  });

  it('allows publish before the start but rejects expiry and cancellation', async () => {
    const future = await create({ startsAt: '2026-10-20T00:00:00Z' });
    expect((await change(future.id, true)).status).toBe(200);
    const expired = await create({ endsAt: '2026-10-15T12:00:00Z' });
    const expiredResult = await change(expired.id, true);
    expect(expiredResult.status).toBe(409);
    expect(expiredResult.body.error.code).toBe('CHALLENGE_EXPIRED');
    const cancelled = await create();
    await ctx.tx(() => sql.exec(`UPDATE challenges SET status='CANCELLED' WHERE id=$1`, [cancelled.id]));
    expect((await change(cancelled.id, true)).body.error.code).toBe('CHALLENGE_CANCELLED');
    expect((await change(cancelled.id, false)).body.data.status).toBe('CANCELLED');
  });

  it('validates explicit booleans, reason, id, and legacy rule values', async () => {
    const row = await create();
    for (const body of [{ enabled: 'false', reason: 'Test reason' }, { enabled: true }, { enabled: true, reason: '  ' }, { enabled: true, reason: 'Test reason', status: 'OPEN' }]) {
      expect((await ctx.api.patch(statusPath(row.id)).set(bearer(token)).send(body)).status).toBe(400);
    }
    expect((await change('invalid-uuid', true)).status).toBe(400);
    expect((await change(randomUUID(), true)).status).toBe(404);
    await ctx.tx(() => sql.exec(`UPDATE challenges SET target=0 WHERE id=$1`, [row.id]));
    const invalid = await change(row.id, true);
    expect(invalid.status).toBe(400);
    expect(invalid.body.error.code).toBe('INVALID_CHALLENGE_CONFIG');
  });

  it('does not modify participation or issue points when toggling', async () => {
    const row = await create();
    const member = await registerMember(ctx.api);
    await ctx.tx(() => sql.exec(`INSERT INTO challenge_participations (tenant_id,challenge_id,member_id,status,progress_value)
      VALUES ($1,$2,$3,'AWAITING_COACH',3)`, [ctx.tenantId, row.id, member.userId]));
    const before = await ctx.tx(() => sql.one('SELECT * FROM challenge_participations WHERE challenge_id=$1', [row.id]));
    await change(row.id, true).expect(200);
    await change(row.id, false).expect(200);
    expect(await ctx.tx(() => sql.one('SELECT * FROM challenge_participations WHERE challenge_id=$1', [row.id]))).toEqual(before);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM point_transactions WHERE challenge_participation_id IN
      (SELECT id FROM challenge_participations WHERE challenge_id=$1)`, [row.id]))).toBe(0);
  });

  it('enforces Admin/Super Admin permission and tenant isolation', async () => {
    const row = await create();
    expect((await ctx.api.patch(statusPath(row.id)).send({ enabled: true, reason: 'No token' })).status).toBe(401);
    for (const role of ['COACH', 'HEAD_COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await ctx.api.patch(statusPath(row.id)).set(bearer(session.token)).send({ enabled: true, reason: 'Wrong role' })).status).toBe(403);
    }
    const member = await registerMember(ctx.api);
    expect((await ctx.api.patch(statusPath(row.id)).set(bearer(member.token)).send({ enabled: true, reason: 'Member role' })).status).toBe(403);
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Other tenant')`, [tenant, `status-${tenant}`]);
    const [foreign] = await ownerQuery<{ id: string }>(`INSERT INTO challenges (tenant_id,title,challenge_type,starts_at,ends_at)
      VALUES ($1,'Foreign challenge','MONTHLY',$2,$3) RETURNING id`, [tenant, input.startsAt, input.endsAt]);
    expect((await change(foreign.id, true)).status).toBe(404);
    const superAdmin = await createStaff({ role: 'ADMIN', fullName: 'Super Admin', phone: nextPhone() });
    await ownerQuery(`UPDATE user_roles SET role_code='SUPER_ADMIN' WHERE user_id=$1`, [superAdmin.userId]);
    const session = await login(ctx.api, superAdmin.phone);
    expect((await ctx.api.patch(statusPath(row.id)).set(bearer(session.token)).send({ enabled: true, reason: 'Super Admin' })).status).toBe(200);
  });

  it('rolls back the status change if audit fails', async () => {
    const row = await create();
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try {
      expect((await change(row.id, true)).status).toBe(500);
      expect(await ctx.tx(() => sql.scalar('SELECT status FROM challenges WHERE id=$1', [row.id]))).toBe('DRAFT');
    } finally { spy.mockRestore(); }
  });
});
