import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { RoleCode } from '../../shared/roles';

export interface UserAuthRow {
  id: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  passwordHash: string;
  accountStatus: 'ACTIVE' | 'LOCKED' | 'DISABLED';
  branchId: string | null;
  avatarUrl: string | null;
  mustChangePassword: boolean;
  authVersion: number;
}

export interface RefreshTokenRow {
  id: string;
  userId: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

export interface ResetRequestRow {
  id: string;
  userId: string;
  channel: 'SMS' | 'EMAIL';
  destination: string;
  pinHash: string;
  attemptCount: number;
  expiresAt: Date;
  verifiedAt: Date | null;
  usedAt: Date | null;
}

export class AuthRepository {
  findUserByEmail(email: string): Promise<UserAuthRow | null> {
    return sql.one<UserAuthRow>(`SELECT * FROM users WHERE email = $1`, [email]);
  }

  findUserByPhone(phone: string): Promise<UserAuthRow | null> {
    return sql.one<UserAuthRow>(`SELECT * FROM users WHERE phone = $1`, [phone]);
  }

  findUserById(id: string): Promise<UserAuthRow | null> {
    return sql.one<UserAuthRow>(`SELECT * FROM users WHERE id = $1`, [id]);
  }

  async rolesOf(userId: string): Promise<RoleCode[]> {
    const rows = await sql.many<{ roleCode: RoleCode }>(
      `SELECT role_code FROM user_roles WHERE user_id = $1 AND revoked_at IS NULL`,
      [userId],
    );
    return rows.map((r) => r.roleCode);
  }

  async memberStatusOf(userId: string): Promise<string | null> {
    const row = await sql.one<{ status: string }>(`SELECT status FROM members WHERE user_id = $1`, [userId]);
    return row?.status ?? null;
  }

  touchLogin(userId: string): Promise<number> {
    return sql.exec(`UPDATE users SET last_login_at = now() WHERE id = $1`, [userId]);
  }

  setPassword(userId: string, passwordHash: string): Promise<number> {
    return sql.exec(`UPDATE users SET password_hash = $2, must_change_password = false, auth_version = auth_version + 1, updated_at = now() WHERE id = $1`, [userId, passwordHash]);
  }

  // ---------- refresh tokens ----------

  insertRefreshToken(input: { userId: string; tokenHash: string; deviceInfo: string | null; expiresAt: Date }): Promise<number> {
    return sql.exec(
      `INSERT INTO refresh_tokens (tenant_id, user_id, token_hash, device_info, expires_at) VALUES ($1,$2,$3,$4,$5)`,
      [db.currentTenantId(), input.userId, input.tokenHash, input.deviceInfo, input.expiresAt],
    );
  }

  findRefreshToken(tokenHash: string): Promise<RefreshTokenRow | null> {
    return sql.one<RefreshTokenRow>(`SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = $1`, [tokenHash]);
  }

  revokeRefreshToken(id: string): Promise<number> {
    return sql.exec(`UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL`, [id]);
  }

  revokeAllForUser(userId: string): Promise<number> {
    return sql.exec(`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, [userId]);
  }

  // ---------- password reset ----------

  insertResetRequest(input: { userId: string; channel: 'SMS' | 'EMAIL'; destination: string; pinHash: string; expiresAt: Date }) {
    return sql.one<{ id: string }>(
      `INSERT INTO password_reset_requests (tenant_id, user_id, channel, destination, pin_hash, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
      [db.currentTenantId(), input.userId, input.channel, input.destination, input.pinHash, input.expiresAt],
    );
  }

  findResetRequest(id: string, lock = false): Promise<ResetRequestRow | null> {
    return sql.one<ResetRequestRow>(`SELECT * FROM password_reset_requests WHERE id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id]);
  }

  bumpResetAttempt(id: string): Promise<number> {
    return sql.exec(`UPDATE password_reset_requests SET attempt_count = attempt_count + 1 WHERE id = $1`, [id]);
  }

  markResetVerified(id: string): Promise<number> {
    return sql.exec(`UPDATE password_reset_requests SET verified_at = now() WHERE id = $1`, [id]);
  }

  markResetUsed(id: string): Promise<number> {
    return sql.exec(`UPDATE password_reset_requests SET used_at = now() WHERE id = $1`, [id]);
  }

  // ---------- logs & devices ----------

  logEvent(input: { userId: string | null; event: 'LOGIN' | 'LOGIN_FAILED' | 'LOGOUT' | 'TOKEN_REFRESH' | 'PASSWORD_RESET'; identifier?: string | null; ip?: string | null; userAgent?: string | null }) {
    return sql.exec(
      `INSERT INTO auth_logs (tenant_id, user_id, event, identifier, ip_address, user_agent) VALUES ($1,$2,$3,$4,$5,$6)`,
      [db.currentTenantId(), input.userId, input.event, input.identifier ?? null, input.ip ?? null, input.userAgent ?? null],
    );
  }

  upsertDeviceToken(input: { userId: string; platform: 'ANDROID' | 'IOS' | 'WEB'; provider: 'FCM' | 'APNS'; token: string }) {
    return sql.exec(
      `INSERT INTO device_tokens (tenant_id, user_id, platform, provider, token)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, is_valid = true, last_seen_at = now()`,
      [db.currentTenantId(), input.userId, input.platform, input.provider, input.token],
    );
  }

  removeDeviceToken(userId: string, token: string): Promise<number> {
    return sql.exec(`DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`, [userId, token]);
  }
}
