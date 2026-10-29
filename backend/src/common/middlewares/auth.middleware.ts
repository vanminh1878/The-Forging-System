import type { NextFunction, Request, Response } from 'express';
import { forbidden, unauthorized } from '../errors/app-error';
import { verifyAccessToken } from '../utils/jwt';
import type { RoleCode } from '../../shared/roles';

/** Verifies the Bearer access token and attaches the principal to req.ctx. */
export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.header('authorization');
  if (!header?.startsWith('Bearer ')) {
    next(unauthorized());
    return;
  }
  try {
    const claims = verifyAccessToken(header.slice(7));
    if (claims.tid !== req.ctx.tenantId) {
      next(forbidden('Token does not belong to this tenant', 'TENANT_MISMATCH'));
      return;
    }
    req.ctx.auth = { userId: claims.sub, roles: claims.roles, branchId: claims.bid ?? null };
    next();
  } catch {
    next(unauthorized('Invalid or expired token', 'TOKEN_INVALID'));
  }
}

/** Allows the request only when the user holds at least one of the roles. */
export function requireRoles(...allowed: readonly RoleCode[]) {
  const middleware = (req: Request, _res: Response, next: NextFunction): void => {
    const roles = req.ctx.auth?.roles ?? [];
    if (!roles.some((r) => allowed.includes(r))) {
      next(forbidden());
      return;
    }
    next();
  };
  // Read by common/http/openapi.ts to generate the API docs.
  return Object.assign(middleware, { openapiRoles: allowed });
}
