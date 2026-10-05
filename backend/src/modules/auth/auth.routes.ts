import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { handle } from '../../common/http/handler';
import { requireAuth } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { isTest } from '../../config/env';
import type { AuthController } from './auth.controller';
import { deviceBody, deviceDeleteBody, forgotBody, loginBody, logoutBody, refreshBody, registerBody, resetBody, verifyPinBody } from './auth.validation';

export function authRoutes(c: AuthController): Router {
  const r = Router();
  // Brute-force protection for credential endpoints (disabled in tests).
  const limiter = rateLimit({ windowMs: 60_000, limit: 20, standardHeaders: true, legacyHeaders: false, skip: () => isTest });

  r.post('/register', limiter, validate({ body: registerBody }), handle(c.register));
  r.post('/login', limiter, validate({ body: loginBody }), handle(c.login));
  r.post('/refresh', limiter, validate({ body: refreshBody }), handle(c.refresh));
  r.post('/logout', requireAuth, validate({ body: logoutBody }), handle(c.logout));
  r.get('/me', requireAuth, handle(c.me));

  r.post('/password/forgot', limiter, validate({ body: forgotBody }), handle(c.forgotPassword));
  r.post('/password/verify-pin', limiter, validate({ body: verifyPinBody }), handle(c.verifyPin));
  r.post('/password/reset', limiter, validate({ body: resetBody }), handle(c.resetPassword));

  r.post('/devices', requireAuth, validate({ body: deviceBody }), handle(c.registerDevice));
  r.delete('/devices', requireAuth, validate({ body: deviceDeleteBody }), handle(c.unregisterDevice));
  return r;
}
