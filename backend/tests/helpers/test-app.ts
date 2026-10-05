import type { Container } from '../../src/container';
import bcrypt from 'bcryptjs';
import request from 'supertest';
import type { Express } from 'express';
import { Client } from 'pg';
import { TEST_DATABASE_MIGRATE_URL } from './test-env';

export const DEFAULT_PASSWORD = 'Passw0rd!';

export interface TestContext {
  app: Express;
  tenantId: string;
  services: Container['services'];
  api: ReturnType<typeof request>;
  /** Runs `fn` inside a tenant transaction (same as a request would). */
  tx<T>(fn: () => Promise<T>): Promise<T>;
}

/** Boots the real Express app against the test database and seeds reference data. */
export async function bootTestApp(): Promise<TestContext> {
  const { createApp } = await import('../../src/app');
  const { db } = await import('../../src/db/database');
  const { lookupTenantByCode, clearTenantCache } = await import('../../src/common/middlewares/tenant.middleware');
  const { seedReferenceData } = await import('../../src/seeds/reference-data');
  const { resetClock } = await import('../../src/common/utils/clock');

  resetClock();
  clearTenantCache();
  await resetData();
  const tenant = await lookupTenantByCode('hvp');
  await seedReferenceData(tenant.id);

  const { app, container } = createApp();
  return {
    app,
    tenantId: tenant.id,
    services: container.services,
    api: request(app),
    tx: (fn) => db.tenantTx(tenant.id, fn),
  };
}

/** Wipes all transactional data (users cascade to everything that references them). */
export async function resetData(): Promise<void> {
  const client = new Client({ connectionString: TEST_DATABASE_MIGRATE_URL });
  await client.connect();
  try {
    await client.query(`TRUNCATE users, branches, courses, package_types, rewards, notifications CASCADE`);
    // Restore the branches shipped with migration 0001.
    await client.query(`
      INSERT INTO branches (tenant_id, code, name, qr_prefix)
      SELECT t.id, b.code, b.name, b.qr_prefix FROM tenants t,
        (VALUES ('Q1','HVP Boxing - The Corner','HVP-CORNER'), ('Q7','HVP Boxing - Riverside','HVP-RIVER')) AS b(code, name, qr_prefix)
      WHERE t.code = 'hvp'`);
  } finally {
    await client.end();
  }
}

export interface StaffSeed {
  role: 'COACH' | 'HEAD_COACH' | 'RECEPTIONIST' | 'ADMIN';
  fullName: string;
  phone: string;
  email?: string;
  branchCode?: string;
}

/** Inserts a staff account directly (staff are provisioned by admins, not self-registered). */
export async function createStaff(seed: StaffSeed): Promise<{ userId: string; phone: string; password: string }> {
  const client = new Client({ connectionString: TEST_DATABASE_MIGRATE_URL });
  await client.connect();
  try {
    const hash = await bcrypt.hash(DEFAULT_PASSWORD, 4);
    const res = await client.query<{ id: string }>(
      `INSERT INTO users (tenant_id, email, phone, password_hash, full_name, branch_id)
       SELECT t.id, $1, $2, $3, $4, (SELECT id FROM branches WHERE code = $5 AND tenant_id = t.id)
         FROM tenants t WHERE t.code = 'hvp' RETURNING id`,
      [seed.email ?? null, seed.phone, hash, seed.fullName, seed.branchCode ?? 'Q1'],
    );
    const userId = res.rows[0].id;
    await client.query(
      `INSERT INTO user_roles (tenant_id, user_id, role_code) SELECT tenant_id, id, $2 FROM users WHERE id = $1`,
      [userId, seed.role],
    );
    return { userId, phone: seed.phone, password: DEFAULT_PASSWORD };
  } finally {
    await client.end();
  }
}

export async function login(api: TestContext['api'], identifier: string, password = DEFAULT_PASSWORD) {
  const res = await api.post('/api/v1/auth/login').send({ identifier, password });
  if (res.status !== 200) throw new Error(`login failed (${res.status}): ${JSON.stringify(res.body)}`);
  return { token: res.body.data.accessToken as string, refreshToken: res.body.data.refreshToken as string, user: res.body.data.user };
}

export const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

let phoneSeq = 0;
export const nextPhone = () => `09${String(10_000_000 + ++phoneSeq + Math.floor(Math.random() * 1000) * 10000).slice(0, 8)}`;

/** Registers a learner through the public API and returns tokens + id. */
export async function registerMember(api: TestContext['api'], overrides: Partial<{ fullName: string; phone: string; email: string }> = {}) {
  const phone = overrides.phone ?? nextPhone();
  const res = await api.post('/api/v1/auth/register').send({
    fullName: overrides.fullName ?? 'Học Viên Test',
    phone,
    email: overrides.email,
    password: DEFAULT_PASSWORD,
  });
  if (res.status !== 201) throw new Error(`register failed (${res.status}): ${JSON.stringify(res.body)}`);
  return { token: res.body.data.accessToken as string, userId: res.body.data.user.id as string, phone };
}

/** Runs a statement with the owner connection (bypasses RLS) - for arranging test fixtures only. */
export async function ownerQuery<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
  const client = new Client({ connectionString: TEST_DATABASE_MIGRATE_URL });
  await client.connect();
  try {
    return (await client.query(text, params)).rows as T[];
  } finally {
    await client.end();
  }
}
