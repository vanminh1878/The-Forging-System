import { createHash } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { badRequest, conflict, forbidden, unauthorized, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { numericPin, randomToken } from '../../common/utils/ids';
import { signAccessToken } from '../../common/utils/jwt';
import { hashPassword, isStrongPassword, verifyPassword } from '../../common/utils/password';
import { normalizePhone } from '../../common/utils/phone';
import { db } from '../../db/database';
import { primaryAppRole } from '../../shared/roles';
import type { AppRole, RoleCode } from '../../shared/roles';
import type { MemberService } from '../members/member.service';
import type { SettingsService } from '../settings/settings.service';
import type { AuthRepository } from './auth.repository';
import type { UserAuthRow } from './auth.repository';
import type { OtpPurpose, OtpSender } from './otp.sender';

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

export interface OtpTicket {
  requestId: string;
  maskedDestination: string;
  /** Development only (console OTP provider). */
  devPin?: string;
}

export interface RequestMeta {
  ip?: string | null;
  userAgent?: string | null;
  deviceInfo?: string | null;
}

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

/** `nguyenvana@gmail.com` -> `ng***@gmail.com` */
export const maskEmail = (email: string) => {
  const [local, domain] = email.split('@');
  return `${local.slice(0, Math.min(2, local.length - 1))}***@${domain}`;
};

const MSG = {
  loginFailed: 'Đăng nhập thất bại. Sai email/số điện thoại hoặc mật khẩu.',
  inactive:
    'Tài khoản không hoạt động. Toàn bộ DP, hạng và HVP Marks vẫn được lưu - liên hệ lễ tân để kích hoạt lại gói tập.',
  pinInvalid: 'Mã PIN không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.',
  otpInvalid: 'Mã xác thực không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.',
  emailNotRegistered: 'Email chưa được đăng ký. Vui lòng kiểm tra lại.',
};

export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly members: MemberService,
    private readonly otp: OtpSender,
    private readonly settings: SettingsService,
  ) {}

  // ---------- registration (e-mail OTP) ----------

  async requestRegisterOtp(email: string): Promise<OtpTicket> {
    if (await this.repo.findUserByEmail(email)) throw conflict('Email đã được đăng ký.', 'EMAIL_TAKEN');
    return this.issueOtp(email, 'REGISTER', async (pin, expiresAt) =>
      (await this.repo.insertEmailOtp({ email, pinHash: sha256(`${email}:${pin}`), expiresAt }))!.id,
    );
  }

  async register(
    input: {
      fullName: string;
      email: string;
      phone: string;
      password: string;
      passwordConfirm?: string;
      homeBranchId?: string;
      otpRequestId: string;
      otp: string;
    },
    meta: RequestMeta,
  ): Promise<AuthTokens> {
    if (input.passwordConfirm !== undefined && input.passwordConfirm !== input.password) {
      throw badRequest('Mật khẩu xác nhận không khớp.');
    }
    const otp = await this.checkPin(
      (max) => this.repo.claimEmailOtpAttempt(input.otpRequestId, max),
      (row, pin) => row.email === input.email && row.pinHash === sha256(`${row.email}:${pin}`),
      input.otp,
      () => badRequest(MSG.otpInvalid, undefined, 'OTP_INVALID'),
    );
    // A failure below (e.g. PHONE_TAKEN) rolls this back, so the OTP stays usable for a retry.
    await this.repo.markEmailOtpUsed(otp.id);
    const { userId } = await this.members.createMember({
      fullName: input.fullName,
      email: input.email,
      phone: input.phone,
      password: input.password,
      homeBranchId: input.homeBranchId ?? null,
    });
    await this.repo.markEmailVerified(userId);
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

  // ---------- password reset (e-mail + PIN) ----------

  async requestPasswordReset(email: string): Promise<OtpTicket> {
    const user = await this.repo.findUserByEmail(email);
    if (!user) throw badRequest(MSG.emailNotRegistered, undefined, 'EMAIL_NOT_REGISTERED');
    return this.issueOtp(email, 'PASSWORD_RESET', async (pin, expiresAt) =>
      (await this.repo.insertResetRequest({
        userId: user.id,
        channel: 'EMAIL',
        destination: email,
        pinHash: sha256(`${user.id}:${pin}`),
        expiresAt,
      }))!.id,
    );
  }

  async verifyPin(requestId: string, pin: string): Promise<{ resetToken: string }> {
    const req = await this.checkPin(
      (max) => this.repo.claimResetAttempt(requestId, max),
      (row, p) => row.pinHash === sha256(`${row.userId}:${p}`),
      pin,
      () => badRequest(MSG.pinInvalid, undefined, 'PIN_INVALID'),
    );
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

  private async issueOtp(email: string, purpose: OtpPurpose, insert: (pin: string, expiresAt: Date) => Promise<string>): Promise<OtpTicket> {
    const ttl = await this.settings.getNumber('security.pin_ttl_minutes');
    const pin = numericPin(6);
    const requestId = await insert(pin, new Date(clock.now().getTime() + ttl * 60_000));
    // The mail goes out only if the transaction commits.
    db.afterCommit(() => this.otp.send(email, pin, purpose, ttl));
    return {
      requestId,
      maskedDestination: maskEmail(email),
      // Convenience for local development only; never returned in production.
      ...(env.NODE_ENV !== 'production' && env.OTP_PROVIDER === 'console' ? { devPin: pin } : {}),
    };
  }

  /**
   * Counts the attempt in a detached transaction first, so it sticks even though
   * a wrong PIN throws (and rolls back the request transaction).
   */
  private async checkPin<T extends { expiresAt: Date }>(
    claim: (maxAttempts: number) => Promise<T | null>,
    matches: (row: T, pin: string) => boolean,
    pin: string,
    invalid: () => Error,
  ): Promise<T> {
    const maxAttempts = await this.settings.getNumber('security.pin_max_attempts');
    const row = await db.detachedTx(() => claim(maxAttempts));
    if (!row || row.expiresAt.getTime() < clock.now().getTime() || !matches(row, pin.trim())) throw invalid();
    return row;
  }

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
    const accessToken = signAccessToken({ sub: userId, tid: db.currentTenantId(), roles, bid: user.branchId });
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
