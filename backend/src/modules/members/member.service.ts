import { badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { env } from '../../config/env';
import { clock } from '../../common/utils/clock';
import { readableCode, randomToken } from '../../common/utils/ids';
import { hashPassword, isStrongPassword } from '../../common/utils/password';
import { isValidEmail, isValidPhone, normalizePhone } from '../../common/utils/phone';
import { sql } from '../../db/sql';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { PointsPort } from '../points/points.service';
import type { RankService } from '../ranks/rank.service';
import type { SettingsService } from '../settings/settings.service';
import type { MemberRepository } from './member.repository';
import type { MemberProfile, ProfilePatch, MemberStatus, StatusChannel } from './member.types';

const STATUS_LABEL: Record<MemberStatus, string> = {
  ACTIVE: 'Hoạt động',
  FROZEN: 'Đóng băng',
  INACTIVE: 'Không hoạt động',
};

const PHONE_TAKEN_MSG = 'Số điện thoại này đã được đăng ký. Mỗi người chỉ có 1 tài khoản dùng chung mọi chi nhánh.';
const EMAIL_TAKEN_MSG = 'Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập.';

export interface CreateMemberInput {
  fullName: string;
  email?: string | null;
  phone?: string | null;
  password?: string;
  homeBranchId?: string | null;
  createdBy?: string | null;
}

/** Account lifecycle for gym members: creation, profile, status rules, duplicate merge. */
export class MemberService {
  constructor(
    private readonly repo: MemberRepository,
    private readonly ranks: RankService,
    private readonly points: PointsPort,
    private readonly notifier: NotifierPort,
    private readonly audit: AuditService,
    private readonly settings: SettingsService,
  ) {}

  /**
   * Creates the user + member profile. One person has exactly one account
   * shared by every branch, so phone and email must be unique per tenant.
   */
  async createMember(input: CreateMemberInput): Promise<{ userId: string; temporaryPassword: string | null }> {
    const fullName = input.fullName.trim();
    const email = input.email?.trim().toLowerCase() || null;
    const phone = input.phone ? normalizePhone(input.phone) : null;
    if (!fullName) throw badRequest('Vui lòng nhập họ tên.');
    if (!phone && !email) throw badRequest('Cần ít nhất số điện thoại hoặc email.');
    if (phone && !isValidPhone(phone)) throw badRequest('Số điện thoại không hợp lệ.');
    if (email && !isValidEmail(email)) throw badRequest('Email không hợp lệ.');

    const minLength = await this.settings.getNumber('security.password_min_length');
    let temporaryPassword: string | null = null;
    let password = input.password;
    if (password === undefined) {
      // Staff-created accounts get a random one-time password shown once to the staff member.
      temporaryPassword = `${randomToken(5)}a1`;
      password = temporaryPassword;
    } else if (!isStrongPassword(password, minLength)) {
      throw badRequest(`Mật khẩu cần tối thiểu ${minLength} ký tự, gồm chữ và số.`, undefined, 'WEAK_PASSWORD');
    }

    if (phone && (await this.exists('phone', phone))) {
      throw conflict(PHONE_TAKEN_MSG, 'PHONE_TAKEN');
    }
    if (email && (await this.exists('email', email))) {
      throw conflict(EMAIL_TAKEN_MSG, 'EMAIL_TAKEN');
    }

    const userId = await this.repo.createMemberAccount({
      fullName,
      email,
      phone,
      passwordHash: await hashPassword(password),
      memberCode: readableCode('HVP'),
      homeBranchId: input.homeBranchId ?? null,
    });
    await this.ranks.initializeMember(userId);
    await this.notifier.notifyMember({
      userId,
      event: NotificationEvent.WELCOME,
      title: 'CHÀO MỪNG TỚI HVP',
      body: 'Tài khoản của bạn đã sẵn sàng. Hãy đăng ký gói tập trong mục Gói tập để bắt đầu.',
    });
    if (input.createdBy) {
      await this.audit.record({ actorId: input.createdBy, action: 'MEMBER_CREATED', entityType: 'MEMBER', entityId: userId, after: { fullName }, reason: 'Học viên mới' });
    }
    return { userId, temporaryPassword };
  }

  async getProfile(memberId: string): Promise<MemberProfile> {
    const profile = await this.repo.findProfile(memberId);
    if (!profile) throw notFound('Member');
    return profile;
  }

  /**
   * Partial profile update (undefined = keep, null = clear). Contact changes are checked for
   * uniqueness and reset the matching verification stamp.
   */
  async updateProfile(userId: string, patch: ProfilePatch): Promise<MemberProfile> {
    const before = await this.getProfile(userId);
    const clean: ProfilePatch = { ...patch };
    if (clean.phone) {
      clean.phone = normalizePhone(clean.phone);
      if (!isValidPhone(clean.phone)) throw badRequest('Số điện thoại không hợp lệ.');
    }
    if (clean.email) {
      clean.email = clean.email.trim().toLowerCase();
      if (!isValidEmail(clean.email)) throw badRequest('Email không hợp lệ.');
    }
    const email = clean.email === undefined ? before.email : clean.email;
    const phone = clean.phone === undefined ? before.phone : clean.phone;
    if (!email && !phone) throw badRequest('Cần giữ lại ít nhất số điện thoại hoặc email.', undefined, 'CONTACT_REQUIRED');

    const phoneChanged = clean.phone !== undefined && clean.phone !== before.phone;
    const emailChanged = clean.email !== undefined && clean.email !== before.email;
    if (phoneChanged && phone && (await this.exists('phone', phone, userId))) throw conflict(PHONE_TAKEN_MSG, 'PHONE_TAKEN');
    if (emailChanged && email && (await this.exists('email', email, userId))) throw conflict(EMAIL_TAKEN_MSG, 'EMAIL_TAKEN');

    if (clean.avatarUrl && !clean.avatarUrl.startsWith(`${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/`)) {
      throw badRequest('Ảnh đại diện không hợp lệ. Vui lòng tải ảnh lên trước rồi chọn lại.', undefined, 'INVALID_AVATAR_URL');
    }
    if (clean.homeBranchId && !(await this.repo.isActiveBranch(clean.homeBranchId))) {
      throw badRequest('Chi nhánh không tồn tại hoặc đã ngừng hoạt động.', undefined, 'INVALID_BRANCH');
    }

    await this.repo.updateUser(userId, { ...clean, resetEmailVerified: emailChanged, resetPhoneVerified: phoneChanged });
    if (clean.homeBranchId !== undefined) await this.repo.setHomeBranch(userId, clean.homeBranchId);

    const after = await this.getProfile(userId);
    const keys = ['fullName', 'avatarUrl', 'email', 'phone', 'dateOfBirth', 'gender', 'homeBranchId'] as const;
    const changed = keys.filter((k) => patch[k] !== undefined);
    await this.audit.record({
      actorId: userId,
      action: 'PROFILE_UPDATED',
      entityType: 'MEMBER',
      entityId: userId,
      before: Object.fromEntries(changed.map((k) => [k, before[k]])),
      after: Object.fromEntries(changed.map((k) => [k, after[k]])),
    });
    return after;
  }

  search(filter: { q?: string; status?: MemberStatus; branchId?: string }, limit: number, offset: number) {
    return Promise.all([this.repo.search(filter, limit, offset), this.repo.countSearch(filter)]).then(([items, total]) => ({ items, total }));
  }

  findDuplicates(memberId: string) {
    return this.repo.findDuplicatesOf(memberId);
  }

  statusCounts() {
    return this.repo.countByStatus();
  }

  /** Records real activity (check-in, confirmed session). Logins do NOT count as activity. */
  touchActivity(memberId: string): Promise<number> {
    return this.repo.touchActivity(memberId, clock.now());
  }

  /**
   * Changes the account status. INACTIVE outranks FROZEN: a frozen status can
   * never overwrite INACTIVE, and only an admin (or a package renewal) can lift INACTIVE.
   */
  async changeStatus(input: {
    memberId: string;
    status: MemberStatus;
    reason: string;
    by: string | null;
    via: StatusChannel;
    actorRoles?: readonly string[];
    notifyMember?: boolean;
  }): Promise<void> {
    if (!input.reason.trim()) throw badRequest('Vui lòng nhập lý do trước khi đổi trạng thái.');
    const profile = await this.getProfile(input.memberId);
    if (profile.status === input.status) return;

    if (profile.status === 'INACTIVE' && input.status === 'FROZEN') {
      throw unprocessable(
        'Tài khoản đang INACTIVE - Inactive có độ ưu tiên cao hơn Freeze. Chỉ Admin hoặc gia hạn gói mới kích hoạt lại.',
        'INACTIVE_PRIORITY',
      );
    }
    if (profile.status === 'INACTIVE' && input.via === 'MANUAL') {
      const roles = input.actorRoles ?? [];
      if (!roles.includes('ADMIN') && !roles.includes('SUPER_ADMIN')) throw forbidden('Chỉ Admin mới kích hoạt lại tài khoản INACTIVE.');
    }

    await this.repo.setStatus(input);
    await this.audit.record({
      actorId: input.by,
      action: 'MEMBERSHIP_STATUS_CHANGED',
      entityType: 'MEMBER',
      entityId: input.memberId,
      before: { status: profile.status },
      after: { status: input.status },
      reason: input.reason,
    });
    if (input.notifyMember !== false) {
      await this.notifier.notifyMember({
        userId: input.memberId,
        event: NotificationEvent.MEMBERSHIP_STATUS,
        title: 'CẬP NHẬT TÀI KHOẢN',
        body: `Tài khoản của bạn đã chuyển sang "${STATUS_LABEL[input.status]}". Lý do: ${input.reason}`,
      });
    }
  }

  /**
   * Merges a duplicate profile into the one that is kept. The ledger is
   * append-only, so the duplicate's balance is moved with a pair of transfer
   * rows (-X on the duplicate, +X on the kept profile) instead of rewriting history.
   */
  async merge(input: { keepId: string; dropId: string; by: string }): Promise<void> {
    if (input.keepId === input.dropId) throw badRequest('Không thể gộp một tài khoản với chính nó.');
    const [keep, drop] = await Promise.all([this.getProfile(input.keepId), this.getProfile(input.dropId)]);
    if (drop.duplicateOfMemberId || keep.duplicateOfMemberId) throw conflict('Một trong hai tài khoản đã được gộp trước đó.', 'ALREADY_MERGED');

    await this.repo.reassignOwnership(drop.userId, keep.userId);

    const transferNote = `Gộp tài khoản trùng (${drop.phone ?? drop.email ?? drop.memberCode}) vào ${keep.fullName}`;
    if (drop.dpBalance !== 0 || drop.marksBalance !== 0) {
      await this.points.award({
        memberId: drop.userId,
        source: 'MANUAL_ADJUSTMENT',
        dp: -drop.dpBalance,
        marks: -drop.marksBalance,
        note: transferNote,
        reason: transferNote,
        by: input.by,
      });
      await this.points.award({
        memberId: keep.userId,
        source: 'MANUAL_ADJUSTMENT',
        dp: drop.dpBalance,
        marks: drop.marksBalance,
        note: `Nhận điểm từ tài khoản trùng ${drop.memberCode}`,
        reason: transferNote,
        by: input.by,
      });
    }
    await sql.exec(
      `UPDATE members SET longest_streak_weeks = GREATEST(longest_streak_weeks, $2), updated_at = now() WHERE user_id = $1`,
      [keep.userId, drop.longestStreakWeeks],
    );
    await this.audit.record({
      actorId: input.by,
      action: 'ACCOUNTS_MERGED',
      entityType: 'MEMBER',
      entityId: keep.userId,
      before: { dropped: drop.userId },
      after: { kept: keep.userId },
      reason: transferNote,
    });
  }

  private async exists(column: 'phone' | 'email', value: string, exceptUserId?: string): Promise<boolean> {
    const n = await sql.scalar<number>(`SELECT count(*) FROM users WHERE ${column} = $1 AND ($2::uuid IS NULL OR id <> $2)`, [value, exceptUserId ?? null]);
    return (n ?? 0) > 0;
  }
}
