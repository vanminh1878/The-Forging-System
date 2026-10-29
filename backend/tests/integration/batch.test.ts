import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Client } from 'pg';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';
import { TEST_DATABASE_MIGRATE_URL } from '../helpers/test-env';
import { jobs } from '../../src/jobs/registry';
import { runJob } from '../../src/jobs/job.runner';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import type { BatchJob } from '../../src/jobs/job.types';

describe('batch: scheduler framework and admin endpoints', () => {
  let ctx: TestContext;
  let admin: string;
  let adminId: string;
  let reception: string;
  let coach: string;
  let original: BatchJob[] = [];
  let seenNow: Date | null = null;
  const fake: BatchJob = {
    key: 'expiry',
    name: 'Job giả',
    cron: '0 1 * * *',
    run: async ({ now }) => {
      seenNow = now;
      return ['dòng 1', 'dòng 2'];
    },
  };
  const boom: BatchJob = { ...fake, key: 'reminder', run: async () => Promise.reject(new Error('hỏng')) };

  beforeAll(async () => {
    ctx = await bootTestApp();
    original = jobs.splice(0, jobs.length, fake, boom);
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminId = a.userId;
    admin = (await login(ctx.api, a.phone)).token;
    const r = await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() });
    reception = (await login(ctx.api, r.phone)).token;
    const c = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    coach = (await login(ctx.api, c.phone)).token;
  });
  afterAll(() => {
    jobs.splice(0, jobs.length, ...original);
    resetClock();
  });

  it('rejects anonymous, coach and reception', async () => {
    for (const [method, url] of [
      ['get', '/api/v1/admin/batch-jobs'],
      ['post', '/api/v1/admin/batch-jobs/expiry/run'],
      ['get', '/api/v1/admin/batch-runs'],
    ] as const) {
      expect((await ctx.api[method](url)).status).toBe(401);
      expect((await ctx.api[method](url).set(bearer(coach))).status).toBe(403);
      expect((await ctx.api[method](url).set(bearer(reception))).status).toBe(403);
    }
  });

  it('lists jobs with no last run, 404 on an unknown key', async () => {
    const res = await ctx.api.get('/api/v1/admin/batch-jobs').set(bearer(admin));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([
      { key: 'expiry', name: 'Job giả', cron: '0 1 * * *', lastRun: null },
      { key: 'reminder', name: 'Job giả', cron: '0 1 * * *', lastRun: null },
    ]);
    const nf = await ctx.api.post('/api/v1/admin/batch-jobs/nope/run').set(bearer(admin));
    expect([nf.status, nf.body.error.code]).toEqual([404, 'NOT_FOUND']);
  });

  it('runs a job by hand: records run_by, lines, clock time and an audit row', async () => {
    const at = new Date('2026-03-02T10:00:00Z');
    setClock(fixedClock(at));
    const res = await ctx.api.post('/api/v1/admin/batch-jobs/expiry/run').set(bearer(admin));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      batchKey: 'expiry',
      status: 'SUCCESS',
      resultLines: ['dòng 1', 'dòng 2'],
      runBy: adminId,
    });
    expect(seenNow?.toISOString()).toBe(at.toISOString());
    const rows = await ownerQuery<{ run_by: string; status: string; started_at: Date }>(
      `SELECT run_by, status, started_at FROM batch_runs WHERE batch_key = 'expiry'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].run_by).toBe(adminId);
    expect(rows[0].started_at.toISOString()).toBe(at.toISOString());
    const audit = await ownerQuery(
      `SELECT 1 FROM audit_logs WHERE action = 'BATCH_RUN' AND entity_type = 'BATCH' AND entity_id = $1 AND actor_id = $2`,
      [res.body.data.id, adminId],
    );
    expect(audit).toHaveLength(1);
    const list = await ctx.api.get('/api/v1/admin/batch-jobs').set(bearer(admin));
    expect(list.body.data[0].lastRun).toMatchObject({ status: 'SUCCESS', lines: ['dòng 1', 'dòng 2'] });
  });

  it('records FAILED (and rolls back job writes) without throwing', async () => {
    const res = await ctx.api.post('/api/v1/admin/batch-jobs/reminder/run').set(bearer(admin));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ status: 'FAILED', resultLines: ['Lỗi: hỏng'] });
  });

  it('records SKIPPED when another process holds the advisory lock; scheduler path has null run_by', async () => {
    const holder = new Client({ connectionString: TEST_DATABASE_MIGRATE_URL });
    await holder.connect();
    try {
      await holder.query('BEGIN');
      await holder.query(`SELECT pg_advisory_xact_lock(hashtext('batch:expiry' || $1::text))`, [
        ctx.tenantId,
      ]);
      const skipped = await runJob(fake, ctx.tenantId, null, ctx.services.audit);
      expect(skipped).toMatchObject({
        status: 'SKIPPED',
        resultLines: ['Job đang chạy ở tiến trình khác.'],
        runBy: null,
      });
      await holder.query('ROLLBACK');
    } finally {
      await holder.end();
    }
    const ok = await runJob(fake, ctx.tenantId, null, ctx.services.audit);
    expect(ok).toMatchObject({ status: 'SUCCESS', runBy: null });
  });

  it('lists run history newest first with filters and validation', async () => {
    const all = await ctx.api.get('/api/v1/admin/batch-runs').set(bearer(admin));
    expect(all.status).toBe(200);
    expect(all.body.meta.total).toBe(4);
    const failed = await ctx.api
      .get('/api/v1/admin/batch-runs?status=FAILED&key=reminder')
      .set(bearer(admin));
    expect(failed.body.data).toHaveLength(1);
    const skipped = await ctx.api.get('/api/v1/admin/batch-runs?status=SKIPPED').set(bearer(admin));
    expect(skipped.body.data).toHaveLength(1);
    expect((await ctx.api.get('/api/v1/admin/batch-runs?status=NOPE').set(bearer(admin))).status).toBe(400);
  });

  it('batch_runs stays append-only', async () => {
    await expect(ownerQuery(`UPDATE batch_runs SET name = 'x'`)).rejects.toThrow(/append-only/);
  });
});
