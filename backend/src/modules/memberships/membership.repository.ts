import { db } from '../../db/database';
import { sql } from '../../db/sql';

export interface PackageTypeRow {
  id: string;
  code: string;
  name: string;
  durationDays: number | null;
  totalSessions: number | null;
  sessionsPerWeek: number | null;
  isTrial: boolean;
  priceVnd: string | null;
  description: string | null;
  isActive: boolean;
}

export interface MembershipRow {
  id: string;
  packageTypeId: string;
  packageCode: string;
  packageName: string;
  isTrial: boolean;
  status: string;
  startDate: string;
  endDate: string | null;
  totalSessions: number | null;
  usedSessions: number;
  paymentEvidenceUrl: string | null;
}

export interface PackageForSale {
  id: string;
  name: string;
  isActive: boolean;
  durationDays: number | null;
  totalSessions: number | null;
  priceVnd: string | null;
}

export interface PendingRenewalRow {
  id: string;
  desiredPackageTypeId: string | null;
  desiredPackageName: string | null;
  desiredPriceVnd: string | null;
  note: string | null;
  createdAt: Date;
}

export interface RenewalRow {
  id: string;
  status: string;
  note: string | null;
  reason: string | null;
  createdAt: Date;
  handledAt: Date | null;
  memberId: string;
  memberName: string;
  memberPhone: string | null;
  memberCode: string;
  desiredPackageTypeId: string | null;
  desiredPackageName: string | null;
  desiredPriceVnd: string | null;
  currentMembershipId: string | null;
  currentPackageName: string | null;
  currentEndDate: string | null;
}

export interface RenewalFilter {
  id?: string;
  memberId?: string;
  status?: string;
  q?: string;
}

const RENEWAL_SELECT = `
  SELECT rr.id, rr.status, rr.note, rr.reason, rr.created_at, rr.handled_at, rr.member_id,
         u.full_name AS member_name, u.phone AS member_phone, m.member_code,
         rr.desired_package_type_id, dpt.name AS desired_package_name, dpt.price_vnd AS desired_price_vnd,
         rr.current_membership_id, cpt.name AS current_package_name, to_char(cms.end_date, 'YYYY-MM-DD') AS current_end_date`;

const RENEWAL_FROM = `
    FROM renewal_requests rr
    JOIN members m ON m.user_id = rr.member_id
    JOIN users u ON u.id = m.user_id
    LEFT JOIN package_types dpt ON dpt.id = rr.desired_package_type_id
    LEFT JOIN memberships cms ON cms.id = rr.current_membership_id
    LEFT JOIN package_types cpt ON cpt.id = cms.package_type_id
   WHERE ($1::uuid IS NULL OR rr.member_id = $1)
     AND ($2::text IS NULL OR rr.status = $2)
     AND ($4::uuid IS NULL OR rr.id = $4)
     AND ($3::text IS NULL OR u.full_name ILIKE '%' || $3 || '%' OR u.phone ILIKE '%' || $3 || '%'
          OR m.member_code ILIKE '%' || $3 || '%')`;

const MEMBERSHIP_SELECT = `
  SELECT ms.id, ms.package_type_id, pt.code AS package_code, pt.name AS package_name, pt.is_trial, ms.status,
         to_char(ms.start_date, 'YYYY-MM-DD') AS start_date, to_char(ms.end_date, 'YYYY-MM-DD') AS end_date,
         ms.total_sessions, ms.used_sessions, ms.payment_evidence_url
    FROM memberships ms
    JOIN package_types pt ON pt.id = ms.package_type_id`;

/** SQL only. Every statement runs in the request's tenant transaction (row level security). */
export class MembershipRepository {
  listPackageTypes(includeInactive: boolean): Promise<PackageTypeRow[]> {
    return sql.many<PackageTypeRow>(
      `SELECT id, code, name, duration_days, total_sessions, sessions_per_week, is_trial, price_vnd, description, is_active
         FROM package_types
        WHERE ($1::boolean OR is_active)
        ORDER BY sort_order, name`,
      [includeInactive],
    );
  }

  /** Account status of a member, or null when the member does not exist. */
  async memberStatus(memberId: string): Promise<string | null> {
    return (
      (await sql.one<{ status: string }>(`SELECT status FROM members WHERE user_id = $1`, [memberId]))
        ?.status ?? null
    );
  }

  /** The member's membership in the given status (at most one ACTIVE and one SCHEDULED exist per member). */
  findByStatus(memberId: string, status: 'ACTIVE' | 'SCHEDULED'): Promise<MembershipRow | null> {
    return sql.one<MembershipRow>(`${MEMBERSHIP_SELECT} WHERE ms.member_id = $1 AND ms.status = $2`, [
      memberId,
      status,
    ]);
  }

  /** True when the member ever had a package that ran its course (COMPLETED or EXPIRED). */
  async hasEndedMembership(memberId: string): Promise<boolean> {
    return (
      (await sql.scalar<number>(
        `SELECT 1 FROM memberships WHERE member_id = $1 AND status IN ('COMPLETED', 'EXPIRED') LIMIT 1`,
        [memberId],
      )) !== null
    );
  }

  findPendingRenewal(memberId: string): Promise<PendingRenewalRow | null> {
    return sql.one<PendingRenewalRow>(
      `SELECT rr.id, rr.desired_package_type_id, pt.name AS desired_package_name, pt.price_vnd AS desired_price_vnd,
              rr.note, rr.created_at
         FROM renewal_requests rr
         LEFT JOIN package_types pt ON pt.id = rr.desired_package_type_id
        WHERE rr.member_id = $1 AND rr.status = 'PENDING'`,
      [memberId],
    );
  }

  /** Package type lookup for the renewal flow. */
  findPackageType(id: string): Promise<{ id: string; name: string; isActive: boolean } | null> {
    return sql.one(`SELECT id, name, is_active FROM package_types WHERE id = $1`, [id]);
  }

  /** Inserts a PENDING request; returns null when the member already has one (unique index race-safe). */
  async insertRenewal(input: {
    memberId: string;
    currentMembershipId: string | null;
    packageTypeId: string;
    note: string | null;
  }): Promise<string | null> {
    const row = await sql.one<{ id: string }>(
      `INSERT INTO renewal_requests (tenant_id, member_id, current_membership_id, desired_package_type_id, note)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (member_id) WHERE status = 'PENDING' DO NOTHING
       RETURNING id`,
      [db.currentTenantId(), input.memberId, input.currentMembershipId, input.packageTypeId, input.note],
    );
    return row?.id ?? null;
  }

  async findRenewal(id: string): Promise<RenewalRow | null> {
    return (await this.listRenewals({ id }, 1, 0)).items[0] ?? null;
  }

  async listRenewals(
    filter: RenewalFilter,
    limit: number,
    offset: number,
  ): Promise<{ items: RenewalRow[]; total: number }> {
    const params = [filter.memberId ?? null, filter.status ?? null, filter.q ?? null, filter.id ?? null];
    const [items, total] = await Promise.all([
      sql.many<RenewalRow>(
        `${RENEWAL_SELECT} ${RENEWAL_FROM} ORDER BY rr.created_at DESC, rr.id LIMIT $5 OFFSET $6`,
        [...params, limit, offset],
      ),
      sql.scalar<string>(`SELECT count(*) ${RENEWAL_FROM}`, params),
    ]);
    return { items, total: Number(total ?? 0) };
  }

  /** Locks the member row for the rest of the transaction; null when the member does not exist. */
  lockMember(memberId: string): Promise<{ status: string; homeBranchId: string | null } | null> {
    return sql.one(`SELECT status, home_branch_id FROM members WHERE user_id = $1 FOR UPDATE`, [memberId]);
  }

  findPackageForSale(id: string): Promise<PackageForSale | null> {
    return sql.one<PackageForSale>(
      `SELECT id, name, is_active, duration_days, total_sessions, price_vnd FROM package_types WHERE id = $1`,
      [id],
    );
  }

  async branchExists(id: string): Promise<boolean> {
    return (await sql.scalar<number>(`SELECT 1 FROM branches WHERE id = $1`, [id])) !== null;
  }

  async latestMembershipId(memberId: string): Promise<string | null> {
    return sql.scalar<string>(
      `SELECT id FROM memberships WHERE member_id = $1 ORDER BY start_date DESC, created_at DESC LIMIT 1`,
      [memberId],
    );
  }

  async expireMembership(id: string, now: Date): Promise<void> {
    await sql.exec(`UPDATE memberships SET status = 'EXPIRED', expired_at = $2, updated_at = $2 WHERE id = $1`, [
      id,
      now,
    ]);
  }

  async insertMembership(input: {
    memberId: string;
    packageTypeId: string;
    branchId: string | null;
    status: 'ACTIVE' | 'SCHEDULED';
    startDate: string;
    endDate: string | null;
    totalSessions: number | null;
    pricePaidVnd: string | null;
    paymentEvidenceUrl: string;
    previousMembershipId: string | null;
    activatedBy: string;
    now: Date;
    note: string | null;
  }): Promise<string> {
    const id = await sql.scalar<string>(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, branch_id, start_date, end_date, total_sessions,
                                status, previous_membership_id, price_paid_vnd, payment_evidence_url, activated_by,
                                activated_at, note)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING id`,
      [
        db.currentTenantId(),
        input.memberId,
        input.packageTypeId,
        input.branchId,
        input.startDate,
        input.endDate,
        input.totalSessions,
        input.status,
        input.previousMembershipId,
        input.pricePaidVnd,
        input.paymentEvidenceUrl,
        input.activatedBy,
        input.now,
        input.note,
      ],
    );
    return id!;
  }

  findMembership(id: string): Promise<MembershipRow | null> {
    return sql.one<MembershipRow>(`${MEMBERSHIP_SELECT} WHERE ms.id = $1`, [id]);
  }

  /** Locks a renewal request so two receptionists cannot approve it at once. */
  lockRenewal(id: string): Promise<{ memberId: string; status: string; desiredPackageTypeId: string | null } | null> {
    return sql.one(
      `SELECT member_id, status, desired_package_type_id FROM renewal_requests WHERE id = $1 FOR UPDATE`,
      [id],
    );
  }

  async completeRenewal(input: {
    id: string;
    by: string;
    now: Date;
    evidenceUrl: string;
    membershipId: string;
    note: string | null;
  }): Promise<void> {
    await sql.exec(
      `UPDATE renewal_requests
          SET status = 'COMPLETED', handled_by = $2, handled_at = $3, payment_evidence_url = $4,
              resulting_membership_id = $5, reason = COALESCE($6, reason), updated_at = $3
        WHERE id = $1`,
      [input.id, input.by, input.now, input.evidenceUrl, input.membershipId, input.note],
    );
  }
}
