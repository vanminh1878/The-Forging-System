import type { Request } from 'express';
import { authOf, created, noContent, ok } from '../../common/http/handler';
import type { HandlerResult } from '../../common/http/handler';
import type { AuthService } from './auth.service';
import type { RequestMeta } from './auth.service';

const metaOf = (req: Request): RequestMeta => ({
  ip: req.ip ?? null,
  userAgent: req.header('user-agent') ?? null,
  deviceInfo: req.header('x-device-info') ?? null,
});

export class AuthController {
  constructor(private readonly service: AuthService) {}

  register = async (req: Request): Promise<HandlerResult> => created(await this.service.register(req.body, metaOf(req)));
  login = async (req: Request): Promise<HandlerResult> => ok(await this.service.login(req.body, metaOf(req)));
  refresh = async (req: Request): Promise<HandlerResult> => ok(await this.service.refresh(req.body.refreshToken, metaOf(req)));

  logout = async (req: Request): Promise<HandlerResult> => {
    await this.service.logout(authOf(req).userId, req.body.refreshToken, metaOf(req));
    return noContent();
  };

  me = async (req: Request): Promise<HandlerResult> => ok(await this.service.me(authOf(req).userId));

  changePassword = async (req: Request): Promise<HandlerResult> => {
    await this.service.changePassword(authOf(req).userId, req.body);
    return noContent();
  };

  forgotPassword = async (req: Request): Promise<HandlerResult> => ok(await this.service.requestPasswordReset(req.body.phone));
  verifyPin = async (req: Request): Promise<HandlerResult> => ok(await this.service.verifyPin(req.body.requestId, req.body.pin));

  resetPassword = async (req: Request): Promise<HandlerResult> => {
    await this.service.resetPassword(req.body);
    return noContent();
  };

  registerDevice = async (req: Request): Promise<HandlerResult> => {
    await this.service.registerDevice(authOf(req).userId, req.body);
    return noContent();
  };

  unregisterDevice = async (req: Request): Promise<HandlerResult> => {
    await this.service.unregisterDevice(authOf(req).userId, req.body.token);
    return noContent();
  };
}
