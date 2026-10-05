import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { db } from '../../db/database';
import { unauthorized } from '../errors/app-error';
import type { AuthContext } from './request-context';

/** What a handler returns; serialised as `{ data, meta }`. */
export interface HandlerResult {
  status: number;
  data?: unknown;
  meta?: unknown;
}

export const ok = (data?: unknown, meta?: unknown): HandlerResult => ({ status: 200, data, meta });
export const created = (data?: unknown): HandlerResult => ({ status: 201, data });
export const noContent = (): HandlerResult => ({ status: 204 });

/**
 * Wraps a controller function:
 *  - opens ONE tenant transaction for the whole request,
 *  - commits it BEFORE the response is written (clients never read stale data),
 *  - forwards any error to the error middleware (transaction rolled back).
 */
export function handle(fn: (req: Request) => Promise<HandlerResult>): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    db.tenantTx(req.ctx.tenantId, () => fn(req))
      .then((result) => {
        if (result.status === 204) {
          res.status(204).end();
          return;
        }
        res.status(result.status).json({ data: result.data ?? null, ...(result.meta ? { meta: result.meta } : {}) });
      })
      .catch(next);
  };
}

/** Returns the authenticated principal or throws 401. */
export function authOf(req: Request): AuthContext {
  if (!req.ctx.auth) throw unauthorized();
  return req.ctx.auth;
}
