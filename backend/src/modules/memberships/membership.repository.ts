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
}

export interface PendingRenewalRow {
  id: string;
  desiredPackageTypeId: string | null;
  desiredPackageName: string | null;
  desiredPriceVnd: string | null;
  note: string | null;
  createdAt: Date;
}

const MEMBERSHIP_SELECT = `
  SELECT ms.id, ms.package_type_id, pt.code AS package_code, pt.name AS package_name, pt.is_trial, ms.status,
         to_char(ms.start_date, 'YYYY-MM-DD') AS start_date, to_char(ms.end_date, 'YYYY-MM-DD') AS end_date,
         ms.total_sessions, ms.used_sessions
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
}
