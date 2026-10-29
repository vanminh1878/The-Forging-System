import { db } from '../../db/database';
import { sql } from '../../db/sql';
import type { MemberProfile, ProfilePatch, MemberStatus, MemberSummary, StatusChannel } from './member.types';

export class MemberRepository {
  /** Inserts the user, the MEMBER role and the gamification profile in one go. */
  async createMemberAccount(input: {
    fullName: string;
    email: string | null;
    phone: string | null;
    passwordHash: string;
    memberCode: string;
    homeBranchId: string | null;
    dateOfBirth?: string | null;
    gender?: string | null;
  }): Promise<string> {
    const tenantId = db.currentTenantId();
    const user = await sql.one<{ id: string }>(
      `INSERT INTO users (tenant_id, email, phone, password_hash, full_name, branch_id, date_of_birth, gender)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
      [tenantId, input.email, input.phone, input.passwordHash, input.fullName, input.homeBranchId, input.dateOfBirth ?? null, input.gender ?? null],
    );
    const userId = user!.id;
    await sql.exec(`INSERT INTO user_roles (tenant_id, user_id, role_code) VALUES ($1,$2,'MEMBER')`, [tenantId, userId]);
    await sql.exec(
      `INSERT INTO members (user_id, tenant_id, member_code, home_branch_id, last_activity_at) VALUES ($1,$2,$3,$4, now())`,
      [userId, tenantId, input.memberCode, input.homeBranchId],
    );
    return userId;
  }

  findProfile(memberId: string): Promise<MemberProfile | null> {
    return sql.one<MemberProfile>(
      `SELECT m.user_id, m.member_code, u.full_name, u.email, u.phone, u.avatar_url, u.date_of_birth, u.gender,
              m.home_branch_id, b.name AS home_branch_name, m.joined_at, m.status, m.status_reason,
              m.status_changed_by, m.status_changed_via, m.status_since, m.current_rank_id, m.peak_rank_id,
              m.dp_balance, m.marks_balance, m.current_streak_weeks, m.longest_streak_weeks, m.last_activity_at,
              m.duplicate_of_member_id
         FROM members m JOIN users u ON u.id = m.user_id LEFT JOIN branches b ON b.id = m.home_branch_id
        WHERE m.user_id = $1`,
      [memberId],
    );
  }

  /** Search used by the reception desk (name / phone / email / member code). */
  search(filter: { q?: string; status?: MemberStatus; branchId?: string; includeDuplicates?: boolean }, limit: number, offset: number) {
    return sql.many<MemberSummary>(
      `SELECT m.user_id, m.member_code, u.full_name, u.phone, u.email, u.avatar_url, m.status, m.current_rank_id,
              r.rank_order, r.name_en AS rank_name, m.dp_balance, m.marks_balance, m.home_branch_id,
              m.last_activity_at, m.current_streak_weeks,
              pt.name AS package_name, ms.end_date AS package_end_date
         FROM members m
         JOIN users u ON u.id = m.user_id
         LEFT JOIN ranks r ON r.id = m.current_rank_id
         LEFT JOIN memberships ms ON ms.member_id = m.user_id AND ms.status = 'ACTIVE'
         LEFT JOIN package_types pt ON pt.id = ms.package_type_id
        WHERE ($1::text IS NULL OR u.full_name ILIKE '%' || $1 || '%' OR u.phone ILIKE '%' || $1 || '%'
               OR u.email::text ILIKE '%' || $1 || '%' OR m.member_code ILIKE '%' || $1 || '%')
          AND ($2::text IS NULL OR m.status = $2)
          AND ($3::uuid IS NULL OR m.home_branch_id = $3)
          AND ($4::boolean OR m.duplicate_of_member_id IS NULL)
        ORDER BY u.full_name
        LIMIT $5 OFFSET $6`,
      [filter.q ?? null, filter.status ?? null, filter.branchId ?? null, filter.includeDuplicates ?? false, limit, offset],
    );
  }

  async countSearch(filter: { q?: string; status?: MemberStatus; branchId?: string; includeDuplicates?: boolean }): Promise<number> {
    return (
      (await sql.scalar<number>(
        `SELECT count(*) FROM members m JOIN users u ON u.id = m.user_id
          WHERE ($1::text IS NULL OR u.full_name ILIKE '%' || $1 || '%' OR u.phone ILIKE '%' || $1 || '%'
                 OR u.email::text ILIKE '%' || $1 || '%' OR m.member_code ILIKE '%' || $1 || '%')
            AND ($2::text IS NULL OR m.status = $2)
            AND ($3::uuid IS NULL OR m.home_branch_id = $3)
            AND ($4::boolean OR m.duplicate_of_member_id IS NULL)`,
        [filter.q ?? null, filter.status ?? null, filter.branchId ?? null, filter.includeDuplicates ?? false],
      )) ?? 0
    );
  }

  /** Other live profiles sharing a phone / email with this member (merge candidates). */
  findDuplicatesOf(memberId: string): Promise<MemberSummary[]> {
    return sql.many<MemberSummary>(
      `SELECT m.user_id, m.member_code, u.full_name, u.phone, u.email, u.avatar_url, m.status, m.current_rank_id,
              m.dp_balance, m.marks_balance, m.home_branch_id, m.last_activity_at, m.current_streak_weeks
         FROM members m JOIN users u ON u.id = m.user_id
         JOIN users me ON me.id = $1
        WHERE m.user_id <> $1 AND m.duplicate_of_member_id IS NULL
          AND ((me.phone IS NOT NULL AND u.phone = me.phone) OR (me.email IS NOT NULL AND u.email = me.email))`,
      [memberId],
    );
  }

  async setStatus(input: {
    memberId: string;
    status: MemberStatus;
    reason: string | null;
    by: string | null;
    via: StatusChannel;
  }): Promise<void> {
    await sql.exec(
      `UPDATE members SET status = $2, status_reason = $3, status_changed_by = $4, status_changed_via = $5,
              status_since = now(), updated_at = now() WHERE user_id = $1`,
      [input.memberId, input.status, input.reason, input.by, input.via],
    );
  }

  touchActivity(memberId: string, at: Date): Promise<number> {
    return sql.exec(`UPDATE members SET last_activity_at = $2, updated_at = now() WHERE user_id = $1`, [memberId, at]);
  }

  /** Partial update: `undefined` keeps the column, an explicit `null` clears it. */
  updateUser(userId: string, patch: ProfilePatch & { resetEmailVerified?: boolean; resetPhoneVerified?: boolean }) {
    const has = (v: unknown) => v !== undefined;
    return sql.exec(
      `UPDATE users SET full_name = COALESCE($2, full_name), avatar_url = CASE WHEN $3::boolean THEN $4 ELSE avatar_url END,
              email = CASE WHEN $5::boolean THEN $6 ELSE email END, phone = CASE WHEN $7::boolean THEN $8 ELSE phone END,
              date_of_birth = CASE WHEN $9::boolean THEN $10::date ELSE date_of_birth END,
              gender = CASE WHEN $11::boolean THEN $12 ELSE gender END,
              email_verified_at = CASE WHEN $13::boolean THEN NULL ELSE email_verified_at END,
              phone_verified_at = CASE WHEN $14::boolean THEN NULL ELSE phone_verified_at END,
              branch_id = CASE WHEN $15::boolean THEN $16::uuid ELSE branch_id END, updated_at = now()
        WHERE id = $1`,
      [
        userId,
        patch.fullName ?? null,
        has(patch.avatarUrl),
        patch.avatarUrl ?? null,
        has(patch.email),
        patch.email ?? null,
        has(patch.phone),
        patch.phone ?? null,
        has(patch.dateOfBirth),
        patch.dateOfBirth ?? null,
        has(patch.gender),
        patch.gender ?? null,
        patch.resetEmailVerified === true,
        patch.resetPhoneVerified === true,
        has(patch.homeBranchId),
        patch.homeBranchId ?? null,
      ],
    );
  }

  setHomeBranch(memberId: string, branchId: string | null): Promise<number> {
    return sql.exec(`UPDATE members SET home_branch_id = $2, updated_at = now() WHERE user_id = $1`, [memberId, branchId]);
  }

  async isActiveBranch(branchId: string): Promise<boolean> {
    return ((await sql.scalar<number>(`SELECT count(*) FROM branches WHERE id = $1 AND is_active`, [branchId])) ?? 0) > 0;
  }

  /**
   * Moves the non-ledger records of a duplicate profile to the profile that is kept.
   * The point ledger is append-only (DB trigger), so balances are carried over by
   * the service with transfer rows instead of rewriting history. Rows that would
   * violate a uniqueness rule on the target are left on the duplicate.
   */
  async reassignOwnership(dropId: string, keepId: string): Promise<void> {
    await sql.exec(
      `UPDATE attendances a SET member_id = $2 WHERE a.member_id = $1
         AND NOT EXISTS (SELECT 1 FROM attendances x WHERE x.session_id = a.session_id AND x.member_id = $2)`,
      [dropId, keepId],
    );
    await sql.exec(`UPDATE redemptions SET member_id = $2 WHERE member_id = $1`, [dropId, keepId]);
    await sql.exec(
      `UPDATE rank_trial_requests t SET member_id = $2 WHERE t.member_id = $1
         AND (t.status NOT IN ('PENDING','SCHEDULED')
              OR NOT EXISTS (SELECT 1 FROM rank_trial_requests x WHERE x.member_id = $2 AND x.status IN ('PENDING','SCHEDULED')))`,
      [dropId, keepId],
    );
    await sql.exec(
      `UPDATE challenge_participations p SET member_id = $2 WHERE p.member_id = $1
         AND NOT EXISTS (SELECT 1 FROM challenge_participations x WHERE x.challenge_id = p.challenge_id AND x.member_id = $2)`,
      [dropId, keepId],
    );
    await sql.exec(
      `UPDATE course_enrollments c SET member_id = $2 WHERE c.member_id = $1 AND c.status = 'COMPLETED'
         AND NOT EXISTS (SELECT 1 FROM course_enrollments x WHERE x.course_id = c.course_id AND x.member_id = $2 AND x.status <> 'DROPPED')`,
      [dropId, keepId],
    );
    await sql.exec(
      `UPDATE members SET duplicate_of_member_id = $2, updated_at = now() WHERE user_id = $1`,
      [dropId, keepId],
    );
    await sql.exec(`UPDATE users SET account_status = 'DISABLED', updated_at = now() WHERE id = $1`, [dropId]);
  }

  async countByStatus(): Promise<Record<string, number>> {
    const rows = await sql.many<{ status: string; n: number }>(
      `SELECT status, count(*) AS n FROM members WHERE duplicate_of_member_id IS NULL GROUP BY status`,
    );
    return Object.fromEntries(rows.map((r) => [r.status, r.n]));
  }
}
