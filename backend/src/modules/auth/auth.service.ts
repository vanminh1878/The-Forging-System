import { createHash } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { badRequest, forbidden, unauthorized, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { numericPin, randomToken } from '../../common/utils/ids';
import { signAccessToken } from '../../common/utils/jwt';
import { hashPassword, isStrongPassword, verifyPassword } from '../../common/utils/password';
import { isValidPhone, normalizePhone } from '../../common/utils/phone';
import { db } from '../../db/database';
import { primaryAppRole } from '../../shared/roles';
import type { AppRole, RoleCode } from '../../shared/roles';
import type { MemberService } from '../members/member.service';
import type { SettingsService } from '../settings/settings.service';
import type { AuthRepository } from './auth.repository';
import type { UserAuthRow } from './auth.repository';
import type { OtpSender } from './otp.sender';

export interface AuthUserView {
  id: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  avatarUrl: string | null;
  roles: RoleCode[];
  appRole: AppRole;
  branchId: string | null;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  /** Access token lifetime hint in seconds. */
  expiresIn: number;
  user: AuthUserView;
}

export interface RequestMeta {
  ip?: string | null;
  userAgent?: string | null;
  deviceInfo?: string | null;
}

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

const MSG = {
  loginFailed: 'Đăng nhập thất bại. Sai email/số điện thoại hoặc mật khẩu.',
  inactive:
    'Tài khoản không hoạt động. Toàn bộ DP, hạng và HVP Marks vẫn được lưu - liên hệ lễ tân để kích hoạt lại gói tập.',
  pinInvalid: 'Mã PIN không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.',
  phoneNotRegistered: 'Số điện thoại chưa được đăng ký. Vui lòng kiểm tra lại.',
};

export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly members: MemberService,
    private readonly otp: OtpSender,
    private readonly settings: SettingsService,
  ) {}

  async register(
    input: { fullName: string; email?: string; phone: string; password: string; passwordConfirm?: string; homeBranchId?: string },
    meta: RequestMeta,
  ): Promise<AuthTokens> {
    if (input.passwordConfirm !== undefined && input.passwordConfirm !== input.password) {
      throw badRequest('Mật khẩu xác nhận không khớp.');
    }
    const { userId } = await this.members.createMember({
      fullName: input.fullName,
      email: input.email,
      phone: input.phone,
      password: input.password,
      homeBranchId: input.homeBranchId ?? null,
    });
    return this.issueTokens(userId, meta, 'LOGIN');
  }

  async login(input: { identifier: string; password: string }, meta: RequestMeta): Promise<AuthTokens> {
    const identifier = input.identifier.trim();
    const user = await this.findByIdentifier(identifier);
    const valid = user ? await verifyPassword(input.password, user.passwordHash) : false;
    if (!user || !valid) {
      await this.repo.logEvent({ userId: user?.id ?? null, event: 'LOGIN_FAILED', identifier, ip: meta.ip, userAgent: meta.userAgent });
      throw unauthorized(MSG.loginFailed, 'INVALID_CREDENTIALS');
    }
    if (user.accountStatus !== 'ACTIVE') throw forbidden('Tài khoản đã bị khóa. Vui lòng liên hệ lễ tân.', 'ACCOUNT_DISABLED');
    // INACTIVE members cannot sign in; FROZEN members can (view-only mode).
    if ((await this.repo.memberStatusOf(user.id)) === 'INACTIVE') {
      throw forbidden(MSG.inactive, 'ACCOUNT_INACTIVE');
    }
    await this.repo.touchLogin(user.id);
    return this.issueTokens(user.id, meta, 'LOGIN');
  }

  async refresh(refreshToken: string, meta: RequestMeta): Promise<AuthTokens> {
    const row = await this.repo.findRefreshToken(sha256(refreshToken));
    if (!row || row.revokedAt || row.expiresAt.getTime() < clock.now().getTime()) {
      throw unauthorized('Phiên đăng nhập đã hết hạn.', 'REFRESH_INVALID');
    }
    const user = await this.repo.findUserById(row.userId);
    if (!user || user.accountStatus !== 'ACTIVE' || (await this.repo.memberStatusOf(user.id)) === 'INACTIVE') {
      throw unauthorized('Phiên đăng nhập đã hết hạn.', 'REFRESH_INVALID');
    }
    await this.repo.revokeRefreshToken(row.id); // rotation: a refresh token is single use
    return this.issueTokens(user.id, meta, 'TOKEN_REFRESH');
  }

  async logout(userId: string, refreshToken: string | undefined, meta: RequestMeta): Promise<void> {
    if (refreshToken) {
      const row = await this.repo.findRefreshToken(sha256(refreshToken));
      if (row && row.userId === userId) await this.repo.revokeRefreshToken(row.id);
    }
    await this.repo.logEvent({ userId, event: 'LOGOUT', ip: meta.ip, userAgent: meta.userAgent });
  }

  async me(userId: string): Promise<AuthUserView> {
    const user = await this.repo.findUserById(userId);
    if (!user) throw unauthorized();
    return this.toView(user, await this.repo.rolesOf(userId));
  }

  // ---------- password reset (phone + PIN) ----------

  async requestPasswordReset(phoneInput: string): Promise<{ requestId: string; maskedDestination: string; devPin?: string }> {
    if (!isValidPhone(phoneInput)) throw badRequest(MSG.phoneNotRegistered);
    const phone = normalizePhone(phoneInput);
    const user = await this.repo.findUserByPhone(phone);
    if (!user) throw badRequest(MSG.phoneNotRegistered, undefined, 'PHONE_NOT_REGISTERED');

    const ttl = await this.settings.getNumber('security.pin_ttl_minutes');
    const pin = numericPin(6);
    const row = await this.repo.insertResetRequest({
      userId: user.id,
      channel: 'SMS',
      destination: phone,
      pinHash: sha256(`${user.id}:${pin}`),
      expiresAt: new Date(clock.now().getTime() + ttl * 60_000),
    });
    // The SMS goes out only if the transaction commits.
    db.afterCommit(() => this.otp.send('SMS', phone, pin));
    return {
      requestId: row!.id,
      maskedDestination: `${phone.slice(0, 3)}****${phone.slice(7)}`,
      // Convenience for local development only; never returned in production.
      ...(env.NODE_ENV !== 'production' && env.OTP_PROVIDER === 'console' ? { devPin: pin } : {}),
    };
  }

  async verifyPin(requestId: string, pin: string): Promise<{ resetToken: string }> {
    const req = await this.repo.findResetRequest(requestId, true);
    const maxAttempts = await this.settings.getNumber('security.pin_max_attempts');
    if (!req || req.usedAt || req.expiresAt.getTime() < clock.now().getTime() || req.attemptCount >= maxAttempts) {
      throw badRequest(MSG.pinInvalid, undefined, 'PIN_INVALID');
    }
    if (req.pinHash !== sha256(`${req.userId}:${pin.trim()}`)) {
      await this.repo.bumpResetAttempt(req.id);
      throw badRequest(`${MSG.pinInvalid} (còn ${Math.max(0, maxAttempts - req.attemptCount - 1)} lần thử)`, undefined, 'PIN_INVALID');
    }
    await this.repo.markResetVerified(req.id);
    const resetToken = jwt.sign({ rid: req.id, uid: req.userId, purpose: 'password-reset' }, env.JWT_ACCESS_SECRET, { expiresIn: '10m' });
    return { resetToken };
  }

  async resetPassword(input: { requestId: string; resetToken: string; password: string; passwordConfirm: string }): Promise<void> {
    let claims: { rid: string; uid: string; purpose: string };
    try {
      claims = jwt.verify(input.resetToken, env.JWT_ACCESS_SECRET) as typeof claims;
    } catch {
      throw badRequest(MSG.pinInvalid, undefined, 'PIN_INVALID');
    }
    if (claims.purpose !== 'password-reset' || claims.rid !== input.requestId) throw badRequest(MSG.pinInvalid, undefined, 'PIN_INVALID');

    const req = await this.repo.findResetRequest(input.requestId, true);
    if (!req || !req.verifiedAt || req.usedAt) throw badRequest(MSG.pinInvalid, undefined, 'PIN_INVALID');

    const min = await this.settings.getNumber('security.password_min_length');
    if (!isStrongPassword(input.password, min) || input.password !== input.passwordConfirm) {
      throw unprocessable(`Mật khẩu cần tối thiểu ${min} ký tự, gồm chữ và số, và phải khớp xác nhận.`, 'WEAK_PASSWORD');
    }
    await this.repo.setPassword(req.userId, await hashPassword(input.password));
    await this.repo.markResetUsed(req.id);
    await this.repo.revokeAllForUser(req.userId);
    await this.repo.logEvent({ userId: req.userId, event: 'PASSWORD_RESET' });
  }

  // ---------- devices ----------

  registerDevice(userId: string, input: { token: string; platform: 'ANDROID' | 'IOS' | 'WEB'; provider?: 'FCM' | 'APNS' }) {
    return this.repo.upsertDeviceToken({ userId, platform: input.platform, provider: input.provider ?? (input.platform === 'IOS' ? 'APNS' : 'FCM'), token: input.token });
  }

  unregisterDevice(userId: string, token: string) {
    return this.repo.removeDeviceToken(userId, token);
  }

  // ---------- internals ----------

  private async findByIdentifier(identifier: string): Promise<UserAuthRow | null> {
    if (identifier.includes('@')) return this.repo.findUserByEmail(identifier.toLowerCase());
    return this.repo.findUserByPhone(normalizePhone(identifier));
  }

  private toView(user: UserAuthRow, roles: RoleCode[]): AuthUserView {
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
      roles,
      appRole: primaryAppRole(roles),
      branchId: user.branchId,
    };
  }

  private async issueTokens(userId: string, meta: RequestMeta, event: 'LOGIN' | 'TOKEN_REFRESH'): Promise<AuthTokens> {
    const user = await this.repo.findUserById(userId);
    if (!user) throw unauthorized();
    const roles = await this.repo.rolesOf(userId);
    const accessToken = signAccessToken({ sub: userId, tid: db.currentTenantId(), roles, bid: user.branchId, ver: user.authVersion });
    const refreshToken = randomToken(32);
    await this.repo.insertRefreshToken({
      userId,
      tokenHash: sha256(refreshToken),
      deviceInfo: meta.deviceInfo ?? meta.userAgent ?? null,
      expiresAt: new Date(clock.now().getTime() + env.REFRESH_TOKEN_TTL_DAYS * 86_400_000),
    });
    await this.repo.logEvent({ userId, event, ip: meta.ip, userAgent: meta.userAgent });
    return { accessToken, refreshToken, expiresIn: ttlSeconds(env.JWT_ACCESS_TTL), user: this.toView(user, roles) };
  }
}

function ttlSeconds(ttl: string): number {
  const m = /^(\d+)([smhd])$/.exec(ttl);
  if (!m) return 900;
  const n = Number(m[1]);
  return n * { s: 1, m: 60, h: 3600, d: 86400 }[m[2] as 's' | 'm' | 'h' | 'd'];
}
