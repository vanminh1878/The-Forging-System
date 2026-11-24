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

describe('admin package types (PKG-01)', () => {
  let ctx: TestContext;
  let admin: string;
  let reception: string;
  let member: string;

  const post = (b: object, t = admin) => ctx.api.post('/api/v1/admin/package-types').set(bearer(t)).send(b);
  const patch = (id: string, b: object, t = admin) =>
    ctx.api.patch(`/api/v1/admin/package-types/${id}`).set(bearer(t)).send(b);

  beforeAll(async () => {
    ctx = await bootTestApp();
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    admin = (await login(ctx.api, a.phone)).token;
    const r = await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() });
    reception = (await login(ctx.api, r.phone)).token;
    member = (await registerMember(ctx.api)).token;
  });

  it('rejects anonymous, member and reception callers', async () => {
    expect((await ctx.api.post('/api/v1/admin/package-types').send({})).status).toBe(401);
    expect((await post({ code: 'X1', name: 'X' }, member)).status).toBe(403);
    expect((await post({ code: 'X1', name: 'X' }, reception)).status).toBe(403);
    expect((await patch('0b8f6a52-1d0e-4c0b-9a55-0b6f3a2f6c11', { name: 'Y' }, reception)).status).toBe(403);
    expect(
      (await ctx.api.patch('/api/v1/admin/package-types/0b8f6a52-1d0e-4c0b-9a55-0b6f3a2f6c11').send({}))
        .status,
    ).toBe(401);
  });

  it('validates the body', async () => {
    for (const bad of [
      {},
      { code: 'lower', name: 'X' },
      { code: 'A B', name: 'X' },
      { code: 'A'.repeat(41), name: 'X' },
      { code: 'OK1', name: '' },
      { code: 'OK1', name: 'X', durationDays: 0 },
      { code: 'OK1', name: 'X', sessionsPerWeek: 15 },
      { code: 'OK1', name: 'X', priceVnd: -1 },
      { code: 'OK1', name: 'X', sortOrder: 1000 },
    ])
      expect((await post(bad)).status).toBe(400);
    expect((await patch('not-a-uuid', { name: 'Y' })).status).toBe(400);
  });

  it('creates a package with defaults, lists it and audits', async () => {
    const res = await post({
      code: 'NEW_PKG',
      name: 'Gói mới',
      durationDays: 30,
      totalSessions: 12,
      priceVnd: 1_500_000,
    });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      code: 'NEW_PKG',
      name: 'Gói mới',
      durationDays: 30,
      totalSessions: 12,
      sessionsPerWeek: null,
      isTrial: false,
      priceVnd: 1_500_000,
      description: null,
      isActive: true,
      sortOrder: 0,
      classCount: 0,
    });
    const list = await ctx.api.get('/api/v1/package-types').set(bearer(member));
    expect(list.body.data.map((p: { code: string }) => p.code)).toContain('NEW_PKG');
    const audit = await ownerQuery(
      `SELECT 1 FROM audit_logs WHERE action = 'PACKAGE_TYPE_CREATED' AND entity_type = 'PACKAGE_TYPE' AND entity_id = $1`,
      [res.body.data.id],
    );
    expect(audit).toHaveLength(1);
  });

  it('answers 409 PACKAGE_CODE_EXISTS for a duplicate code', async () => {
    const dup = await post({ code: 'BOOK_1', name: 'Trùng' });
    expect([dup.status, dup.body.error.code, dup.body.error.message]).toEqual([
      409,
      'PACKAGE_CODE_EXISTS',
      'Mã gói đã tồn tại',
    ]);
    const id = (await post({ code: 'OTHER_PKG', name: 'Other' })).body.data.id;
    const clash = await patch(id, { code: 'BOOK_1' });
    expect([clash.status, clash.body.error.code]).toEqual([409, 'PACKAGE_CODE_EXISTS']);
    expect((await patch(id, { code: 'OTHER_PKG', name: 'Same code ok' })).status).toBe(200);
  });

  it('patches fields, clears optional ones and can retire a package', async () => {
    const id = (
      await post({
        code: 'PATCH_ME',
        name: 'Patch',
        priceVnd: 100000,
        description: 'mô tả',
        sessionsPerWeek: 3,
      })
    ).body.data.id;
    expect((await patch(id, {})).status).toBe(400);
    const res = await patch(id, {
      name: 'Đã sửa',
      priceVnd: null,
      description: null,
      isActive: false,
      sortOrder: 7,
    });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      name: 'Đã sửa',
      priceVnd: null,
      description: null,
      isActive: false,
      sortOrder: 7,
      sessionsPerWeek: 3,
    });
    const forMember = await ctx.api.get('/api/v1/package-types').set(bearer(member));
    expect(forMember.body.data.map((p: { code: string }) => p.code)).not.toContain('PATCH_ME');
    const audit = await ownerQuery(
      `SELECT 1 FROM audit_logs WHERE action = 'PACKAGE_TYPE_UPDATED' AND entity_id = $1`,
      [id],
    );
    expect(audit).toHaveLength(1);
    const missing = await patch('0b8f6a52-1d0e-4c0b-9a55-0b6f3a2f6c11', { name: 'x' });
    expect([missing.status, missing.body.error.code]).toEqual([404, 'NOT_FOUND']);
  });

  it('reports classCount of active classes in GET /package-types', async () => {
    const pkg = (await post({ code: 'WITH_CLASSES', name: 'Có lớp' })).body.data.id;
    const q1 = (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = 'Q1'`))[0].id;
    for (const active of [true, true, false])
      await ownerQuery(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes, is_active, package_type_id)
         SELECT tenant_id, $1, 'L', 'GROUP', '{1}', '18:00', 60, $2, $3 FROM branches WHERE id = $1`,
        [q1, active, pkg],
      );
    const list = await ctx.api.get('/api/v1/package-types').set(bearer(member));
    expect(list.body.data.find((p: { code: string }) => p.code === 'WITH_CLASSES').classCount).toBe(2);
    expect(list.body.data.find((p: { code: string }) => p.code === 'BOOK_1').classCount).toBe(0);
  });
});
