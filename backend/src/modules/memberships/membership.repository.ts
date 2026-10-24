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
}
