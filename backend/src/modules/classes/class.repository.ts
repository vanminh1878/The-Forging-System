import { db } from '../../db/database';
import { sql } from '../../db/sql';
import { RoleGroup } from '../../shared/roles';
import type { ClassInput, ClassRow, RosterEntry, SessionInput, SessionRecord, SessionRow, SessionTypeRow } from './class.types';

const COLUMNS = `id, branch_id, name, session_type_code, course_id, default_coach_id, weekdays::int[] AS weekdays,
  to_char(start_time, 'HH24:MI') AS start_time, duration_minutes, capacity, is_active`;

const SESSION_COLUMNS = `id, class_id, branch_id, session_type_code, coach_id, lesson_plan_id, title, starts_at, ends_at,
  max_dp_override, is_exam, capacity, status, notes`;
const SESSION_SELECT = `SELECT ${SESSION_COLUMNS} FROM sessions`;

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

  // ---- session generation (CLS-02) ----

  activeClasses(classId?: string): Promise<ClassRow[]> {
    return sql.many(
      `SELECT ${COLUMNS} FROM classes WHERE is_active AND ($1::uuid IS NULL OR id = $1) ORDER BY name, id`,
      [classId ?? null],
    );
  }

  /** Inserts the given start instants for a class; existing (class, start) pairs are skipped, and so are cancelled ones (a cancelled session is never regenerated). Returns the number created. */
  insertSessions(cls: ClassRow, coachId: string, startsAt: Date[]): Promise<number> {
    return sql.exec(
      `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at, capacity)
       SELECT $1, $2, $3, $4, $5, $6, s, s + make_interval(mins => $7::int), $8
         FROM unnest($9::timestamptz[]) AS s
        WHERE NOT EXISTS (SELECT 1 FROM sessions x WHERE x.class_id = $2 AND x.starts_at = s AND x.status = 'CANCELLED')
       ON CONFLICT DO NOTHING`,
      [db.currentTenantId(), cls.id, cls.branchId, cls.sessionTypeCode, coachId, cls.name, cls.durationMinutes, cls.capacity, startsAt],
    );
  }

  /** Future SCHEDULED sessions of a class, with whether anyone already has an attendance row. */
  futureScheduledSessions(classId: string, from: Date): Promise<Array<{ id: string; branchId: string; startsAt: Date; endsAt: Date; hasAttendance: boolean }>> {
    return sql.many(
      `SELECT s.id, s.branch_id, s.starts_at, s.ends_at,
              EXISTS (SELECT 1 FROM attendances a WHERE a.session_id = s.id) AS has_attendance
         FROM sessions s WHERE s.class_id = $1 AND s.status = 'SCHEDULED' AND s.starts_at >= $2 ORDER BY s.starts_at`,
      [classId, from],
    );
  }

  deleteSessions(ids: string[]): Promise<number> {
    return sql.exec(`DELETE FROM sessions WHERE id = ANY($1::uuid[])`, [ids]);
  }

  cancelSessions(ids: string[]): Promise<number> {
    return sql.exec(`UPDATE sessions SET status = 'CANCELLED', updated_at = now() WHERE id = ANY($1::uuid[])`, [ids]);
  }

  setFutureCoach(classId: string, coachId: string, from: Date): Promise<number> {
    return sql.exec(
      `UPDATE sessions SET coach_id = $2, updated_at = now()
        WHERE class_id = $1 AND status = 'SCHEDULED' AND starts_at >= $3 AND coach_id <> $2`,
      [classId, coachId, from],
    );
  }

  listSessions(classId: string, from: Date, to: Date): Promise<Array<Omit<SessionRow, 'date'>>> {
    return sql.many<Omit<SessionRow, 'coach' | 'date'> & { coachId: string; coachName: string }>(
      `SELECT s.id, s.class_id, s.title, s.starts_at, s.ends_at, s.status, s.is_exam, s.capacity,
              s.coach_id, u.full_name AS coach_name,
              (SELECT COUNT(*)::int FROM attendances a WHERE a.session_id = s.id) AS attendee_count
         FROM sessions s JOIN users u ON u.id = s.coach_id
        WHERE s.class_id = $1 AND s.starts_at >= $2 AND s.starts_at < $3 ORDER BY s.starts_at, s.id`,
      [classId, from, to],
    ).then((rows) =>
      rows.map(({ coachId, coachName, ...r }) => ({ ...r, coach: { id: coachId, fullName: coachName } }) as Omit<SessionRow, 'date'>),
    );
  }

  // ---- one-off / exam / cancelled sessions (CLS-03) ----

  sessionType(code: string): Promise<SessionTypeRow | null> {
    return sql.one(`SELECT code, max_dp, max_dp_upper FROM session_types WHERE code = $1 AND is_active`, [code]);
  }

  async lessonPlanExists(id: string): Promise<boolean> {
    return !!(await sql.scalar(`SELECT 1 FROM lesson_plans WHERE id = $1`, [id]));
  }

  /** How many of the ids are members. */
  async countMembers(ids: string[]): Promise<number> {
    return (await sql.scalar<number>(`SELECT COUNT(*)::int FROM members WHERE user_id = ANY($1::uuid[])`, [ids])) ?? 0;
  }

  /** The coach already has a non-cancelled session overlapping [from, to). */
  async coachBusy(coachId: string, from: Date, to: Date): Promise<boolean> {
    return !!(await sql.scalar(
      `SELECT 1 FROM sessions WHERE coach_id = $1 AND status <> 'CANCELLED' AND starts_at < $3 AND ends_at > $2 LIMIT 1`,
      [coachId, from, to],
    ));
  }

  /** The non-cancelled session of the class that starts exactly at the instant, if any. */
  classSessionAt(classId: string, startsAt: Date): Promise<SessionRecord | null> {
    return sql.one(`${SESSION_SELECT} WHERE class_id = $1 AND starts_at = $2 AND status <> 'CANCELLED'`, [classId, startsAt]);
  }

  findSession(id: string, lock = false): Promise<SessionRecord | null> {
    return sql.one(`${SESSION_SELECT} WHERE id = $1${lock ? ' FOR UPDATE' : ''}`, [id]);
  }

  async insertSession(i: SessionInput): Promise<SessionRecord> {
    const row = await sql.one<SessionRecord>(
      `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, lesson_plan_id, title, starts_at, ends_at,
                             max_dp_override, is_exam, capacity, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING ${SESSION_COLUMNS}`,
      [db.currentTenantId(), i.classId, i.branchId, i.sessionTypeCode, i.coachId, i.lessonPlanId, i.title, i.startsAt, i.endsAt,
       i.maxDpOverride, i.isExam, i.capacity, i.notes, i.createdBy],
    );
    return row as SessionRecord;
  }

  addAttendances(sessionId: string, memberIds: string[]): Promise<number> {
    return sql.exec(
      `INSERT INTO attendances (tenant_id, session_id, member_id)
       SELECT $1, $2, m FROM unnest($3::uuid[]) AS m ON CONFLICT (session_id, member_id) DO NOTHING`,
      [db.currentTenantId(), sessionId, memberIds],
    );
  }

  markExam(id: string, title: string, lessonPlanId: string | null): Promise<SessionRecord | null> {
    return sql.one(
      `UPDATE sessions SET is_exam = true, title = $2, lesson_plan_id = COALESCE($3, lesson_plan_id), updated_at = now()
        WHERE id = $1 RETURNING ${SESSION_COLUMNS}`,
      [id, title, lessonPlanId],
    );
  }

  cancelSession(id: string): Promise<number> {
    return sql.exec(`UPDATE sessions SET status = 'CANCELLED', updated_at = now() WHERE id = $1`, [id]);
  }

  /** ACTIVE members who have an attendance row for the session or are enrolled in its class on its local date. */
  sessionRecipients(sessionId: string, tz: string): Promise<string[]> {
    return sql
      .many<{ memberId: string }>(
        `SELECT DISTINCT m.user_id AS member_id
           FROM sessions s
           JOIN members m ON m.status = 'ACTIVE'
          WHERE s.id = $1
            AND (EXISTS (SELECT 1 FROM attendances a WHERE a.session_id = s.id AND a.member_id = m.user_id)
              OR EXISTS (SELECT 1 FROM class_enrollments e
                          WHERE e.class_id = s.class_id AND e.member_id = m.user_id AND e.status <> 'CANCELLED'
                            AND (s.starts_at AT TIME ZONE $2)::date >= e.start_date
                            AND (e.end_date IS NULL OR (s.starts_at AT TIME ZONE $2)::date <= e.end_date)))`,
        [sessionId, tz],
      )
      .then((rows) => rows.map((r) => r.memberId));
  }
}
