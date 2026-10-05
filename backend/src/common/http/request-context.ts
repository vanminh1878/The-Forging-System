import type { RoleCode } from '../../shared/roles';

export interface AuthContext {
  userId: string;
  roles: RoleCode[];
  branchId: string | null;
}

export interface RequestContext {
  tenantId: string;
  auth?: AuthContext;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      ctx: RequestContext;
    }
  }
}

export {};
