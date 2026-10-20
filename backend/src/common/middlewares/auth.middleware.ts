import type { NextFunction, Request, Response } from 'express';
import { forbidden, unauthorized } from '../errors/app-error';
import { verifyAccessToken } from '../utils/jwt';
import type { RoleCode } from '../../shared/roles';
import { db } from '../../db/database';
import { AuthRepository } from '../../modules/auth/auth.repository';

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
    db.tenantTx(req.ctx.tenantId, async () => {
      const repo = new AuthRepository();
      const user = await repo.findUserById(claims.sub);
      if (!user || user.accountStatus !== 'ACTIVE') throw forbidden('Tài khoản không hoạt động.', 'ACCOUNT_DISABLED');
      if (user.authVersion !== (claims.ver ?? 0)) throw unauthorized('Phiên đăng nhập đã hết hạn.', 'TOKEN_INVALID');
      const allowedDuringPasswordChange = ['/me', '/logout', '/password/change'];
      if (user.mustChangePassword && !(req.baseUrl.endsWith('/auth') && allowedDuringPasswordChange.includes(req.path))) {
        throw forbidden('Bạn phải đổi mật khẩu tạm trước khi tiếp tục.', 'PASSWORD_CHANGE_REQUIRED');
      }
      req.ctx.auth = { userId: user.id, roles: await repo.rolesOf(user.id), branchId: user.branchId };
    }).then(() => next()).catch(next);
  } catch {
    next(unauthorized('Invalid or expired token', 'TOKEN_INVALID'));
  }
}

/** Allows the request only when the user holds at least one of the roles. */
export function requireRoles(...allowed: readonly RoleCode[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const roles = req.ctx.auth?.roles ?? [];
    if (!roles.some((r) => allowed.includes(r))) {
      next(forbidden());
      return;
    }
    next();
  };
}
