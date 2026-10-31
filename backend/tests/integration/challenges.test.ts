import { randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('CHL-01 admin Challenge APIs', () => {
  let ctx: TestContext;
  let adminToken: string;
  let adminId: string;
  const input = { title: 'Boxing Challenge', challengeType: 'MONTHLY', context: 'SESSION', target: 3, rewardDp: 100, rewardMarks: 40, startsAt: '2026-10-01T00:00:00+07:00', endsAt: '2026-11-01T00:00:00+07:00' };

  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Challenge Admin', phone: nextPhone() });
    adminId = admin.userId;
    adminToken = (await login(ctx.api, admin.phone)).token;
  });

  async function create(patch: Record<string, unknown> = {}) {
    const result = await ctx.api.post('/api/v1/admin/challenges').set(bearer(adminToken)).send({ ...input, ...patch });
    expect(result.status, JSON.stringify(result.body)).toBe(201);
    return result.body.data;
  }

  it('creates a DRAFT with defaults, normalized code, actor, and audit', async () => {
    const row = await create({ code: ' oct_test ', description: 'Test description' });
    expect(row).toMatchObject({ status: 'DRAFT', code: 'OCT_TEST', createdBy: adminId, rewardDp: 100 });
    expect(row.tenantId).toBeUndefined();
    const audit = await ctx.tx(() => sql.one<{ action: string; actorId: string }>('SELECT action, actor_id FROM audit_logs WHERE entity_id=$1', [row.id]));
    expect(audit).toMatchObject({ action: 'CHALLENGE_CREATED', actorId: adminId });
    const detail = await ctx.api.get(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken));
    expect(detail.status).toBe(200);
    expect(detail.body.data.id).toBe(row.id);
    const defaults = await ctx.api.post('/api/v1/admin/challenges').set(bearer(adminToken))
      .send({ title: 'Defaults only', challengeType: 'DAILY', startsAt: input.startsAt, endsAt: input.endsAt });
    expect(defaults.status).toBe(201);
    expect(defaults.body.data).toMatchObject({ context: 'SESSION', target: 1, rewardDp: 0, rewardMarks: 0, code: null, description: null });
  });

  it('updates fields without publishing, records before/after, and does not audit no-ops', async () => {
    const row = await create();
    const patch = { title: 'Updated title', rewardDp: 0, description: null, reason: 'Update draft' };
    const response = await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send(patch);
    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({ title: patch.title, rewardDp: 0, status: 'DRAFT' });
    const audit = await ctx.tx(() => sql.one<{ beforeData: { title: string }; afterData: { title: string } }>(`SELECT before_data, after_data FROM audit_logs WHERE entity_id=$1 AND action='CHALLENGE_UPDATED'`, [row.id]));
    expect(audit?.beforeData.title).toBe(input.title);
    expect(audit?.afterData.title).toBe(patch.title);
    await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send(patch).expect(200);
    const count = await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='CHALLENGE_UPDATED'`, [row.id]));
    expect(count).toBe(1);
  });

  it('validates create/partial dates, protected fields, duplicate codes, and missing objects', async () => {
    const row = await create({ code: 'UNIQUE_CODE' });
    expect((await ctx.api.post('/api/v1/admin/challenges').set(bearer(adminToken)).send({ ...input, code: 'unique_code' })).status).toBe(409);
    for (const patch of [{ target: 0 }, { status: 'OPEN' }, { rewardMarks: -1 }, { createdBy: adminId }]) {
      expect((await ctx.api.post('/api/v1/admin/challenges').set(bearer(adminToken)).send({ ...input, ...patch })).status).toBe(400);
    }
    const date = await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send({ startsAt: input.endsAt, reason: 'Invalid start' });
    expect(date.status).toBe(400);
    expect(date.body.error.code).toBe('INVALID_CHALLENGE_DATES');
    expect((await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send({ reason: 'No changes' })).status).toBe(400);
    expect((await ctx.api.get(`/api/v1/admin/challenges/${randomUUID()}`).set(bearer(adminToken))).status).toBe(404);
  });

  it('searches literal wildcards, filters, and paginates', async () => {
    await create({ title: 'Literal 100% _ success' });
    await create({ title: 'Literal ordinary success' });
    const result = await ctx.api.get('/api/v1/admin/challenges').set(bearer(adminToken))
      .query({ q: '100% _', status: 'DRAFT', challengeType: 'MONTHLY', context: 'SESSION', page: 1, limit: 1 });
    expect(result.status).toBe(200);
    expect(result.body.data).toHaveLength(1);
    expect(result.body.meta).toMatchObject({ page: 1, limit: 1, total: 1 });
    expect(result.body.data[0].title).toBe('Literal 100% _ success');
  });

  it('blocks rule edits after joining, allows metadata, and never alters participation or points', async () => {
    const row = await create();
    const member = await registerMember(ctx.api);
    await ctx.tx(async () => {
      await sql.exec(`INSERT INTO challenge_participations (tenant_id,challenge_id,member_id) VALUES ($1,$2,$3)`, [ctx.tenantId, row.id, member.userId]);
    });
    const blocked = await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send({ rewardDp: 500, reason: 'Change reward' });
    expect(blocked.status).toBe(409);
    expect(blocked.body.error.code).toBe('CHALLENGE_RULES_LOCKED');
    await ctx.api.patch(`/api/v1/admin/challenges/${row.id}`).set(bearer(adminToken)).send({ title: 'Metadata fix', reason: 'Fix spelling' }).expect(200);
    const participation = await ctx.tx(() => sql.one<{ status: string; progressValue: number }>('SELECT status, progress_value FROM challenge_participations WHERE challenge_id=$1', [row.id]));
    expect(participation).toEqual({ status: 'JOINED', progressValue: 0 });
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM point_transactions WHERE challenge_participation_id IN (SELECT id FROM challenge_participations WHERE challenge_id=$1)', [row.id]))).toBe(0);
  });

  it('denies unauthenticated/non-admin callers and permits Super Admin', async () => {
    expect((await ctx.api.post('/api/v1/admin/challenges').send(input)).status).toBe(401);
    for (const role of ['COACH', 'HEAD_COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await ctx.api.post('/api/v1/admin/challenges').set(bearer(session.token)).send(input)).status).toBe(403);
    }
    const member = await registerMember(ctx.api);
    expect((await ctx.api.get('/api/v1/admin/challenges').set(bearer(member.token))).status).toBe(403);
    const superAdmin = await createStaff({ role: 'ADMIN', fullName: 'Super Admin', phone: nextPhone() });
    await ownerQuery(`UPDATE user_roles SET role_code='SUPER_ADMIN' WHERE user_id=$1`, [superAdmin.userId]);
    const session = await login(ctx.api, superAdmin.phone);
    expect((await ctx.api.post('/api/v1/admin/challenges').set(bearer(session.token)).send(input)).status).toBe(201);
  });

  it('isolates tenant reads/writes and allows same code in different tenants', async () => {
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Other tenant')`, [tenant, `chl-${tenant}`]);
    const [foreign] = await ownerQuery<{ id: string }>(`INSERT INTO challenges (tenant_id,code,title,challenge_type,starts_at,ends_at)
      VALUES ($1,'CROSS_TENANT','Foreign challenge','DAILY',$2,$3) RETURNING id`, [tenant, input.startsAt, input.endsAt]);
    const foreignPath = `/api/v1/admin/challenges/${foreign.id}`;
    expect((await ctx.api.get(foreignPath).set(bearer(adminToken))).status).toBe(404);
    expect((await ctx.api.patch(foreignPath).set(bearer(adminToken)).send({ title: 'Overwrite', reason: 'Invalid tenant' })).status).toBe(404);
    const list = await ctx.api.get('/api/v1/admin/challenges?q=Foreign').set(bearer(adminToken));
    expect(list.body.data).toHaveLength(0);
    await create({ code: 'CROSS_TENANT' });
  });

  it('rolls back Challenge insertion if audit fails', async () => {
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try {
      const result = await ctx.api.post('/api/v1/admin/challenges').set(bearer(adminToken)).send({ ...input, code: 'ROLLBACK_CHL' });
      expect(result.status).toBe(500);
      expect(await ctx.tx(() => sql.scalar('SELECT 1 FROM challenges WHERE code=$1', ['ROLLBACK_CHL']))).toBeNull();
    } finally { spy.mockRestore(); }
  });
});
