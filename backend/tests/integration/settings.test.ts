import { randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it } from 'vitest';
import { db } from '../../src/db/database';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('CFG-01 settings APIs', () => {
  let ctx: TestContext;
  let token: string;
  let adminId: string;
  const base = '/api/v1/admin/settings';
  beforeAll(async () => {
    ctx = await bootTestApp();
    const admin = await createStaff({ role: 'ADMIN', fullName: 'Config Admin', phone: nextPhone() });
    adminId = admin.userId;
    token = (await login(ctx.api, admin.phone)).token;
  });
  const put = (key: string, body: Record<string, unknown>) => ctx.api.put(`${base}/${key}`).set(bearer(token)).send(body);

  it('reads defaults, individual settings and group/search filters', async () => {
    const response = await ctx.api.get(`${base}/points.dp_monthly_cap`).set(bearer(token));
    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({ key: 'points.dp_monthly_cap', value: 1200, isDefault: true, updatedAt: null, updatedBy: null });
    const list = await ctx.api.get(base).set(bearer(token)).query({ group: 'STREAK', q: 'freeze' });
    expect(list.status).toBe(200);
    expect(list.body.data.length).toBeGreaterThan(0);
    expect(list.body.data.every((entry: { group: string; key: string }) => entry.group === 'STREAK' && entry.key.includes('freeze'))).toBe(true);
    expect((await ctx.api.get(`${base}/unknown.key`).set(bearer(token))).status).toBe(404);
  });

  it('audits both first override and updates exactly once and keeps no-op timestamps', async () => {
    const key = 'points.attitude_dp';
    await put(key, { value: 12, reason: 'First override' }).expect(204);
    await put(key, { value: 15, reason: 'Tune points' }).expect(204);
    const before = await ctx.api.get(`${base}/${key}`).set(bearer(token));
    await put(key, { value: 15, reason: 'Repeated value' }).expect(204);
    const after = await ctx.api.get(`${base}/${key}`).set(bearer(token));
    expect(after.body.data).toMatchObject({ value: 15, isDefault: false, updatedBy: adminId });
    expect(after.body.data.updatedAt).toBe(before.body.data.updatedAt);
    const logs = await ctx.tx(() => sql.many<{ beforeData: unknown; afterData: unknown; reason: string; actorId: string }>(`SELECT before_data,after_data,reason,actor_id FROM audit_logs
      WHERE entity_type='SYSTEM_CONFIG' AND entity_id=$1 ORDER BY id`, [key]));
    expect(logs).toHaveLength(2);
    expect(logs[0]).toEqual({ beforeData: null, afterData: 12, reason: 'First override', actorId: adminId });
    expect(logs[1]).toMatchObject({ beforeData: 12, afterData: 15, reason: 'Tune points' });
  });

  it('validates scalar and JSON types/ranges while preserving value-only requests', async () => {
    await put('rank.demotion_enabled', { value: false }).expect(204);
    await put('points.dp_monthly_cap', { value: 0 }).expect(204);
    await put('streak.milestones', { value: { '4': 25, '8': 50 } }).expect(204);
    for (const [key, value] of [['points.dp_monthly_cap', -1], ['points.dp_monthly_cap', 1.5], ['points.dp_monthly_cap', '100'], ['rank.demotion_enabled', 'false'], ['streak.milestones', []], ['streak.milestones', { '4': -1 }], ['security.password_min_length', 73]] as const) {
      const result = await put(key, { value });
      expect(result.status).toBe(400);
      expect(result.body.error.code).toBe('INVALID_CONFIG_VALUE');
    }
    expect((await put('unknown.key', { value: 1 })).body.error.code).toBe('UNKNOWN_CONFIG_KEY');
    expect((await put('points.dp_monthly_cap', {})).status).toBe(400);
    expect((await put('points.dp_monthly_cap', { value: 1, unexpected: true })).status).toBe(400);
    expect((await ctx.api.get(`${base}?group=INVALID`).set(bearer(token))).status).toBe(400);
  });

  it('does not leak cached values across pooled transactions or tenants', async () => {
    const key = 'points.marks_monthly_cap';
    const first = await ctx.tx(async () => ({ client: db.current(), value: await ctx.services.settings.getNumber(key) }));
    await put(key, { value: 175 }).expect(204);
    const second = await ctx.tx(() => ctx.services.settings.getNumber(key));
    expect(first.value).toBe(150);
    expect(second).toBe(175);
    const foreign = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign config')`, [foreign, foreign]);
    expect(await db.tenantTx(foreign, () => ctx.services.settings.getNumber(key))).toBe(150);
    expect(await ctx.tx(() => ctx.services.settings.getNumber(key))).toBe(175);
  });

  it('rolls back value and audit together', async () => {
    const key = 'armory.low_stock_threshold';
    await expect(ctx.tx(async () => {
      await ctx.services.settings.set(key, 12, adminId, 'Rollback example');
      expect(await ctx.services.settings.getNumber(key)).toBe(12);
      throw new Error('Rollback');
    })).rejects.toThrow('Rollback');
    expect(await ctx.tx(() => ctx.services.settings.getNumber(key))).toBe(3);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_type='SYSTEM_CONFIG' AND entity_id=$1`, [key]))).toBe(0);
  });

  it('enforces Admin permission for reads and writes', async () => {
    expect((await ctx.api.get(base)).status).toBe(401);
    for (const role of ['COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await ctx.api.get(base).set(bearer(session.token))).status).toBe(403);
      expect((await ctx.api.put(`${base}/points.dp_monthly_cap`).set(bearer(session.token)).send({ value: 10 })).status).toBe(403);
    }
    const member = await registerMember(ctx.api);
    expect((await ctx.api.get(base).set(bearer(member.token))).status).toBe(403);
  });
});
