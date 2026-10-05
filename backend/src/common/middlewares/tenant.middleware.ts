import type { NextFunction, Request, Response } from 'express';
import { env } from '../../config/env';
import { db } from '../../db/database';
import { AppError } from '../errors/app-error';

interface TenantRow {
  id: string;
  code: string;
}

const cache = new Map<string, { value: TenantRow; expiresAt: number }>();
const TTL_MS = 60_000;

export async function lookupTenantByCode(code: string): Promise<TenantRow> {
  const hit = cache.get(code);
  if (hit && hit.expiresAt > Date.now()) return hit.value;
  const res = await db.system.query<TenantRow>(
    'SELECT id, code FROM tenants WHERE code = $1 AND is_active = true',
    [code],
  );
  const row = res.rows[0];
  if (!row) throw new AppError(400, 'UNKNOWN_TENANT', `Unknown tenant "${code}"`);
  cache.set(code, { value: row, expiresAt: Date.now() + TTL_MS });
  return row;
}

export async function lookupActiveTenantIds(): Promise<TenantRow[]> {
  const res = await db.system.query<TenantRow>('SELECT id, code FROM tenants WHERE is_active = true ORDER BY code');
  return res.rows;
}

/**
 * Resolves the tenant for the request from the `X-Tenant-Code` header, falling
 * back to DEFAULT_TENANT_CODE (single-tenant deployments need no header).
 * The auth middleware later verifies that the JWT belongs to the same tenant.
 */
export function resolveTenant(req: Request, _res: Response, next: NextFunction): void {
  const code = (req.header('x-tenant-code') ?? env.DEFAULT_TENANT_CODE).trim().toLowerCase();
  lookupTenantByCode(code)
    .then((tenant) => {
      req.ctx = { tenantId: tenant.id };
      next();
    })
    .catch(next);
}

/** Test helper. */
export function clearTenantCache(): void {
  cache.clear();
}
