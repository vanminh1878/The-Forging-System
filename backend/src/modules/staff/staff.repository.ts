import { sql } from '../../db/sql';
import type { RoleCode } from '../../shared/roles';

export interface StaffView {
  id: string;
  fullName: string;
  phone: string | null;
  email: string | null;
  branchId: string | null;
  branchName: string | null;
  accountStatus: string;
  mustChangePassword: boolean;
  roles: RoleCode[];
}
export interface StaffFilter { q?: string; role?: string; branchId?: string; status?: string }
const projection = `u.id, u.full_name, u.phone, u.email, u.branch_id, b.name AS branch_name,
  u.account_status, u.must_change_password,
  ARRAY(SELECT role_code FROM user_roles WHERE user_id=u.id AND revoked_at IS NULL ORDER BY role_code) AS roles`;
const staffOnly = `EXISTS (SELECT 1 FROM user_roles r WHERE r.user_id=u.id AND r.revoked_at IS NULL AND r.role_code <> 'MEMBER')`;

export class StaffRepository {
  async search(filter: StaffFilter, limit: number, offset: number) {
    const params = [filter.q ? `%${filter.q.replace(/[\\%_]/g, '\\$&')}%` : null, filter.role ?? null, filter.branchId ?? null, filter.status ?? null];
    const where = `${staffOnly}
      AND ($1::text IS NULL OR u.full_name ILIKE $1 OR u.email ILIKE $1 OR u.phone ILIKE $1)
      AND ($2::text IS NULL OR EXISTS (SELECT 1 FROM user_roles r WHERE r.user_id=u.id AND r.revoked_at IS NULL AND r.role_code=$2))
      AND ($3::uuid IS NULL OR u.branch_id=$3) AND ($4::text IS NULL OR u.account_status=$4)`;
    const items = await sql.many<StaffView>(`SELECT ${projection} FROM users u LEFT JOIN branches b ON b.id=u.branch_id WHERE ${where} ORDER BY u.full_name, u.id LIMIT $5 OFFSET $6`, [...params, limit, offset]);
    const count = await sql.one<{ total: number }>(`SELECT count(*)::int AS total FROM users u WHERE ${where}`, params);
    return { items, total: count!.total };
  }

  find(id: string) { return sql.one<StaffView>(`SELECT ${projection} FROM users u LEFT JOIN branches b ON b.id=u.branch_id WHERE u.id=$1 AND ${staffOnly}`, [id]); }

}
