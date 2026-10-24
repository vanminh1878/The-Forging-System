import type { NextFunction, Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ user: vi.fn(), roles: vi.fn(), verify: vi.fn() }));
vi.mock('../../src/common/utils/jwt', () => ({ verifyAccessToken: mocks.verify }));
vi.mock('../../src/db/database', () => ({ db: { tenantTx: (_tenant: string, fn: () => Promise<void>) => fn() } }));
vi.mock('../../src/modules/auth/auth.repository', () => ({ AuthRepository: class { findUserById = mocks.user; rolesOf = mocks.roles; } }));
import { requireAuth } from '../../src/common/middlewares/auth.middleware';

describe('live credential checks for staff accounts', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    mocks.verify.mockReturnValue({ sub: 'user', tid: 'tenant', roles: ['ADMIN'], bid: 'old-branch', ver: 2 });
    mocks.user.mockResolvedValue({ id: 'user', accountStatus: 'ACTIVE', mustChangePassword: false, authVersion: 2, branchId: 'new-branch' });
    mocks.roles.mockResolvedValue(['COACH']);
  });

  async function authenticate(path = '/members', baseUrl = '/api/v1') {
    const req = { path, baseUrl, header: () => 'Bearer test', ctx: { tenantId: 'tenant' } } as unknown as Request;
    const error = await new Promise<unknown>((resolve) => requireAuth(req, {} as Response, resolve as NextFunction));
    return { req, error };
  }

  it('uses current roles and branch rather than stale token claims', async () => {
    const { req, error } = await authenticate();
    expect(error).toBeUndefined();
    expect(req.ctx.auth).toEqual({ userId: 'user', roles: ['COACH'], branchId: 'new-branch' });
  });

  it('rejects disabled accounts and revoked credential generations', async () => {
    mocks.user.mockResolvedValueOnce({ accountStatus: 'DISABLED', authVersion: 2 });
    expect((await authenticate()).error).toMatchObject({ code: 'ACCOUNT_DISABLED' });
    mocks.user.mockResolvedValueOnce({ accountStatus: 'ACTIVE', authVersion: 3 });
    expect((await authenticate()).error).toMatchObject({ code: 'TOKEN_INVALID' });
  });

  it('enforces a temporary password even on an already issued token', async () => {
    mocks.user.mockResolvedValue({ id: 'user', accountStatus: 'ACTIVE', authVersion: 2, mustChangePassword: true });
    expect((await authenticate()).error).toMatchObject({ code: 'PASSWORD_CHANGE_REQUIRED' });
    for (const path of ['/me', '/logout', '/password/change']) {
      expect((await authenticate(path, '/api/v1/auth')).error).toBeUndefined();
    }
    expect((await authenticate('/me', '/api/v1')).error).toMatchObject({ code: 'PASSWORD_CHANGE_REQUIRED' });
  });

  it('rejects tenant mismatches before reading account data', async () => {
    mocks.verify.mockReturnValue({ tid: 'another-tenant' });
    expect((await authenticate()).error).toMatchObject({ code: 'TENANT_MISMATCH' });
    expect(mocks.user).not.toHaveBeenCalled();
  });
});
