import { randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it } from 'vitest';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('CFG-10 Audit Log filters', () => {
  let ctx: TestContext;
  let token: string;
  let adminId: string;
  let coachToken: string;
  let coachId: string;
  const path = '/api/v1/admin/audit-logs';
  const action = 'TEST_TRACE';

  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Trace Administrator', phone: nextPhone() });
    adminId = admin.userId;
    token = (await login(ctx.api, admin.phone)).token;
    const coach = await createStaff({ role: 'COACH', fullName: 'Trace Coach', phone: nextPhone() });
    coachId = coach.userId;
    coachToken = (await login(ctx.api, coach.phone)).token;
    await ownerQuery(`INSERT INTO audit_logs (tenant_id,actor_id,actor_type,action,entity_type,entity_id,before_data,after_data,reason,created_at)
      VALUES ($1,$2,'USER',$4,'TEST_AUDIT','first','{"dp":0}','{"dp":10}','100% verified','2026-10-03T03:00:00Z'),
      ($1,$2,'USER',$4,'TEST_AUDIT','old-import','{}','{}','Old record inserted later','2026-10-01T03:00:00Z'),
      ($1,$3,'USER',$4,'TEST_AUDIT','same-time','{}','{}','Coach confirmation','2026-10-03T03:00:00Z'),
      ($1,NULL,'SYSTEM',$4,'TEST_AUDIT','system',NULL,'{"streak":4}','Scheduler weekly','2026-10-04T03:00:00Z')`,
    [ctx.tenantId, adminId, coachId, action]);
  });
  const get = (query: Record<string, unknown> = {}) => ctx.api.get(path).set(bearer(token)).query(query);

  it('orders by time then ID and returns consistent paginated totals', async () => {
    const result = await get({ action, page: 2, limit: 1 });
    expect(result.status).toBe(200);
    expect(result.body.meta).toMatchObject({ page: 2, limit: 1, total: 4, totalPages: 4 });
    expect(result.body.data[0].entityId).toBe('same-time');
    const all = await get({ action });
    expect(all.body.data.map((entry: { entityId: string }) => entry.entityId)).toEqual(['system', 'same-time', 'first', 'old-import']);
    expect(all.body.data[0].tenantId).toBeUndefined();
    expect(all.body.data[2]).toMatchObject({ beforeData: { dp: 0 }, afterData: { dp: 10 } });
  });

  it('combines actor, entity, action and date filters', async () => {
    const result = await get({ action, entityType: 'TEST_AUDIT', entityId: 'first', actorId: adminId, actorType: 'USER',
      from: '2026-10-02T00:00:00Z', to: '2026-10-04T00:00:00Z' });
    expect(result.status).toBe(200);
    expect(result.body.meta.total).toBe(1);
    expect(result.body.data[0]).toMatchObject({ actorId: adminId, actorName: 'Trace Administrator', entityId: 'first' });
    const equal = await get({ action, from: '2026-10-03T10:00:00+07:00', to: '2026-10-03T10:00:00+07:00' });
    expect(equal.status).toBe(200);
    expect(equal.body.meta.total).toBe(2);
  });

  it('finds SYSTEM entries and searches literal text or actor names', async () => {
    const system = await get({ action, actorType: 'SYSTEM' });
    expect(system.body.data).toHaveLength(1);
    expect(system.body.data[0]).toMatchObject({ actorId: null, actorName: null });
    const literal = await get({ action, q: '%' });
    expect(literal.body.meta.total).toBe(1);
    expect(literal.body.data[0].entityId).toBe('first');
    const actor = await get({ action, q: 'trace coach' });
    expect(actor.body.data).toHaveLength(1);
    expect(actor.body.data[0].actorId).toBe(coachId);
    expect((await get({ action: "' OR true --" })).body.data).toHaveLength(0);
    expect((await get({ action, page: 99 })).body.data).toHaveLength(0);
  });

  it('rejects invalid filters instead of silently ignoring them', async () => {
    for (const query of [{ actorId: 'bad' }, { actorType: 'ADMIN' }, { action: ' ' }, { page: 0 }, { limit: 101 },
      { from: '2026-10-04T00:00:00Z', to: '2026-10-01T00:00:00Z' }, { from: 'not-date' }, { unknown: 'value' }]) {
      const response = await get(query);
      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('reads settings change audit end-to-end by textual config key', async () => {
    const key = 'checkin.code_ttl_seconds';
    await ctx.api.put(`/api/v1/admin/settings/${key}`).set(bearer(token)).send({ value: 90, reason: 'CFG trace example' }).expect(204);
    const result = await get({ action: 'CONFIG_CHANGE', entityType: 'SYSTEM_CONFIG', entityId: key, actorId: adminId, q: 'CFG trace example' });
    expect(result.body.meta.total).toBe(1);
    expect(result.body.data[0]).toMatchObject({ beforeData: null, afterData: 90, actorId: adminId, actorName: 'Trace Administrator' });
  });

  it('enforces permissions and tenant isolation', async () => {
    expect((await ctx.api.get(path)).status).toBe(401);
    expect((await ctx.api.get(path).set(bearer(coachToken))).status).toBe(403);
    const member = await registerMember(ctx.api);
    expect((await ctx.api.get(path).set(bearer(member.token))).status).toBe(403);
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Audit foreign')`, [tenant, tenant]);
    await ownerQuery(`INSERT INTO audit_logs (tenant_id,actor_type,action,entity_type,entity_id,reason)
      VALUES ($1,'SYSTEM',$2,'TEST_AUDIT','foreign','Tenant secret')`, [tenant, action]);
    const result = await get({ action });
    expect(result.body.meta.total).toBe(4);
    expect((await get({ action, entityId: 'foreign' })).body.data).toHaveLength(0);
    const superAdmin = await createStaff({ role: 'ADMIN', fullName: 'Super Admin', phone: nextPhone() });
    await ownerQuery(`UPDATE user_roles SET role_code='SUPER_ADMIN' WHERE user_id=$1`, [superAdmin.userId]);
    const session = await login(ctx.api, superAdmin.phone);
    expect((await ctx.api.get(path).set(bearer(session.token))).status).toBe(200);
  });

  it('keeps audit read-only and append-only', async () => {
    const id = await ctx.tx(() => sql.scalar<number>(`SELECT id FROM audit_logs WHERE action=$1 LIMIT 1`, [action]));
    expect((await ctx.api.patch(`${path}/${id}`).set(bearer(token)).send({ reason: 'Overwrite' })).status).toBe(404);
    await expect(ownerQuery(`UPDATE audit_logs SET reason='Overwrite' WHERE id=$1`, [id])).rejects.toBeTruthy();
    await expect(ownerQuery('DELETE FROM audit_logs WHERE id=$1', [id])).rejects.toBeTruthy();
  });
});
