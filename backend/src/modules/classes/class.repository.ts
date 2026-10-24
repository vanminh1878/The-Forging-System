import { db } from '../../db/database';
import { sql } from '../../db/sql';
import { RoleGroup } from '../../shared/roles';
import type { ClassInput, ClassRow, RosterEntry } from './class.types';

const COLUMNS = `id, branch_id, name, session_type_code, course_id, default_coach_id, weekdays::int[] AS weekdays,
  to_char(start_time, 'HH24:MI') AS start_time, duration_minutes, capacity, is_active`;

export interface ClassFilter {
  branchId?: string;
  sessionTypeCode?: string;
  isActive?: boolean;
}

export class ClassRepository {
  async list(f: ClassFilter, limit: number, offset: number): Promise<{ rows: Array<ClassRow & { enrolledCount: number }>; total: number }> {
    const where = `($1::uuid IS NULL OR branch_id = $1) AND ($2::text IS NULL OR session_type_code = $2)
      AND ($3::boolean IS NULL OR is_active = $3)`;
    const params = [f.branchId ?? null, f.sessionTypeCode ?? null, f.isActive ?? null];
    const rows = await sql.many<ClassRow & { enrolledCount: number }>(
      `SELECT ${COLUMNS},
         (SELECT COUNT(*)::int FROM class_enrollments e WHERE e.class_id = classes.id AND e.status = 'ACTIVE') AS enrolled_count
         FROM classes WHERE ${where} ORDER BY name, start_time, id LIMIT $4 OFFSET $5`,
      [...params, limit, offset],
    );
    const total = await sql.scalar<number>(`SELECT COUNT(*)::int FROM classes WHERE ${where}`, params);
    return { rows, total: total ?? 0 };
  }

  /** `lock` serialises concurrent enrollments so the capacity check cannot be raced. */
  findById(id: string, lock = false): Promise<ClassRow | null> {
    return sql.one(`SELECT ${COLUMNS} FROM classes WHERE id = $1${lock ? ' FOR UPDATE' : ''}`, [id]);
  }

  async insert(i: ClassInput): Promise<ClassRow> {
    const row = await sql.one<ClassRow>(
      `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, course_id, default_coach_id, weekdays, start_time, duration_minutes, capacity, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7::smallint[], $8, $9, $10, $11)
       RETURNING ${COLUMNS}`,
      [db.currentTenantId(), i.branchId, i.name, i.sessionTypeCode, i.courseId, i.defaultCoachId, i.weekdays, i.startTime, i.durationMinutes, i.capacity, i.isActive],
    );
    return row as ClassRow;
  }

  async update(id: string, i: ClassInput): Promise<ClassRow> {
    const row = await sql.one<ClassRow>(
      `UPDATE classes SET branch_id = $2, name = $3, session_type_code = $4, course_id = $5, default_coach_id = $6,
         weekdays = $7::smallint[], start_time = $8, duration_minutes = $9, capacity = $10, is_active = $11, updated_at = now()
       WHERE id = $1 RETURNING ${COLUMNS}`,
      [id, i.branchId, i.name, i.sessionTypeCode, i.courseId, i.defaultCoachId, i.weekdays, i.startTime, i.durationMinutes, i.capacity, i.isActive],
    );
    return row as ClassRow;
  }

  async branchIsActive(id: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM branches WHERE id = $1 AND is_active`, [id]));
  }

  async sessionTypeExists(code: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM session_types WHERE code = $1 AND is_active`, [code]));
  }

  async courseExists(id: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM courses WHERE id = $1`, [id]));
  }

  async isCoach(userId: string): Promise<boolean> {
    return !!(await sql.scalar(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role_code = ANY($2::text[]) AND revoked_at IS NULL`,
      [userId, [...RoleGroup.COACHING_STAFF]],
    ));
  }

  /** Null when the member does not exist. */
  memberState(memberId: string): Promise<{ status: string; merged: boolean } | null> {
    return sql.one(`SELECT status, duplicate_of_member_id IS NOT NULL AS merged FROM members WHERE user_id = $1`, [memberId]);
  }

  async membershipBelongsTo(membershipId: string, memberId: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM memberships WHERE id = $1 AND member_id = $2`, [membershipId, memberId]));
  }

  async countActive(classId: string): Promise<number> {
    return (await sql.scalar<number>(`SELECT COUNT(*)::int FROM class_enrollments WHERE class_id = $1 AND status = 'ACTIVE'`, [classId])) ?? 0;
  }

  async hasActiveEnrollment(classId: string, memberId: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM class_enrollments WHERE class_id = $1 AND member_id = $2 AND status = 'ACTIVE'`, [classId, memberId]));
  }

  roster(classId: string): Promise<RosterEntry[]> {
    return sql.many(
      `SELECT e.id AS enrollment_id, e.member_id, m.member_code, u.full_name, e.membership_id,
              e.start_date::text AS start_date, e.end_date::text AS end_date
         FROM class_enrollments e
         JOIN members m ON m.user_id = e.member_id
         JOIN users u ON u.id = e.member_id
        WHERE e.class_id = $1 AND e.status = 'ACTIVE'
        ORDER BY u.full_name, e.id`,
      [classId],
    );
  }

  async insertEnrollment(i: {
    classId: string;
    memberId: string;
    membershipId: string | null;
    startDate: string;
    endDate: string | null;
    by: string;
  }): Promise<string> {
    const id = await sql.scalar<string>(
      `INSERT INTO class_enrollments (tenant_id, class_id, member_id, membership_id, start_date, end_date, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [db.currentTenantId(), i.classId, i.memberId, i.membershipId, i.startDate, i.endDate, i.by],
    );
    return id as string;
  }

  /** Returns the ended enrollment id, or null when the member has no active enrollment. */
  endEnrollment(classId: string, memberId: string, today: string): Promise<string | null> {
    return sql.scalar<string>(
      `UPDATE class_enrollments SET status = 'ENDED', end_date = $3
        WHERE class_id = $1 AND member_id = $2 AND status = 'ACTIVE' RETURNING id`,
      [classId, memberId, today],
    );
  }
}
