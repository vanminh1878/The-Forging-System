import { env } from '../../config/env';
import { sql } from '../../db/sql';

export interface ScheduleRow {
  sessionId: string;
  classId: string | null;
  title: string | null;
  sessionType: string;
  isExam: boolean;
  startsAt: Date;
  endsAt: Date;
  sessionStatus: string;
  notes: string | null;
  branchId: string;
  branchName: string;
  coachId: string;
  coachName: string;
  attendanceStatus: string | null;
  checkinAt: Date | null;
  completionPercent: number | null;
  lessonPlanId: string | null;
  lessonPlanTitle: string | null;
}

export interface ScheduleFilter {
  from?: Date;
  to?: Date;
  branchId?: string;
  sessionId?: string;
}

export interface CoachClassRow {
  id: string;
  name: string;
  branchId: string;
  branchName: string;
  sessionType: string;
  weekdays: number[];
  startTime: string;
  durationMinutes: number;
  enrolledCount: number;
}

export interface CoachSessionRow {
  sessionId: string;
  classId: string | null;
  className: string | null;
  title: string | null;
  sessionType: string;
  isExam: boolean;
  status: string;
  startsAt: Date;
  endsAt: Date;
  branchId: string;
  branchName: string;
  lessonPlanId: string | null;
  lessonPlanTitle: string | null;
  registered: number;
  checkedIn: number;
  reviewed: number;
}

export interface RosterRow {
  memberId: string;
  memberCode: string;
  fullName: string;
  avatarUrl: string | null;
  rankOrder: number | null;
  rankName: string | null;
  otherBranch: boolean;
  attendanceStatus: string | null;
  checkinAt: Date | null;
  completionPercent: number | null;
  dpAwarded: number | null;
  coachNote: string | null;
  academyResult: string | null;
}

/** Learners of session `s`: anyone with an attendance row plus those enrolled in its class on its local date (same rule as CLS-04). */
const rosterIds = (tz: string) => `
  SELECT a.member_id FROM attendances a WHERE a.session_id = s.id
  UNION
  SELECT e.member_id FROM class_enrollments e
   WHERE e.class_id = s.class_id AND e.status <> 'CANCELLED'
     AND (s.starts_at AT TIME ZONE ${tz})::date >= e.start_date
     AND (e.end_date IS NULL OR (s.starts_at AT TIME ZONE ${tz})::date <= e.end_date)`;

export class ScheduleRepository {
  /**
   * Sessions that belong to the learner: either he has an attendance row, or he is enrolled
   * (any non-cancelled enrollment) in the session's class on the session's local date.
   */
  find(memberId: string, f: ScheduleFilter): Promise<ScheduleRow[]> {
    return sql.many(
      `SELECT s.id AS session_id, s.class_id, s.title, s.session_type_code AS session_type, s.is_exam,
              s.starts_at, s.ends_at, s.status AS session_status, s.notes,
              b.id AS branch_id, b.name AS branch_name, u.id AS coach_id, u.full_name AS coach_name,
              a.attendance_status, a.checkin_at, a.completion_percent,
              lp.id AS lesson_plan_id, lp.title AS lesson_plan_title
         FROM sessions s
         JOIN branches b ON b.id = s.branch_id
         JOIN users u ON u.id = s.coach_id
         LEFT JOIN lesson_plans lp ON lp.id = s.lesson_plan_id
         LEFT JOIN attendances a ON a.session_id = s.id AND a.member_id = $1
        WHERE ($2::timestamptz IS NULL OR s.starts_at >= $2)
          AND ($3::timestamptz IS NULL OR s.starts_at < $3)
          AND ($4::uuid IS NULL OR s.branch_id = $4)
          AND ($5::uuid IS NULL OR s.id = $5)
          AND (a.id IS NOT NULL OR EXISTS (
                SELECT 1 FROM class_enrollments e
                 WHERE e.class_id = s.class_id AND e.member_id = $1 AND e.status <> 'CANCELLED'
                   AND (s.starts_at AT TIME ZONE $6)::date >= e.start_date
                   AND (e.end_date IS NULL OR (s.starts_at AT TIME ZONE $6)::date <= e.end_date)))
        ORDER BY s.starts_at, s.id`,
      [memberId, f.from ?? null, f.to ?? null, f.branchId ?? null, f.sessionId ?? null, env.APP_TIMEZONE],
    );
  }

  // ---- coach side (CLS-05): always scoped to sessions.coach_id = the coach ----

  coachClasses(coachId: string): Promise<CoachClassRow[]> {
    return sql.many(
      `SELECT c.id, c.name, b.id AS branch_id, b.name AS branch_name, c.session_type_code AS session_type,
              c.weekdays::int[] AS weekdays, to_char(c.start_time, 'HH24:MI') AS start_time, c.duration_minutes,
              (SELECT COUNT(*)::int FROM class_enrollments e WHERE e.class_id = c.id AND e.status = 'ACTIVE') AS enrolled_count
         FROM classes c JOIN branches b ON b.id = c.branch_id
        WHERE c.is_active AND c.default_coach_id = $1 ORDER BY c.name, c.start_time, c.id`,
      [coachId],
    );
  }

  coachSessions(coachId: string, from: Date, to: Date): Promise<CoachSessionRow[]> {
    return sql.many(
      `SELECT s.id AS session_id, s.class_id, c.name AS class_name, s.title, s.session_type_code AS session_type, s.is_exam,
              s.status, s.starts_at, s.ends_at, b.id AS branch_id, b.name AS branch_name,
              lp.id AS lesson_plan_id, lp.title AS lesson_plan_title,
              (SELECT COUNT(*)::int FROM (${rosterIds('$4')}) r) AS registered,
              (SELECT COUNT(*)::int FROM attendances a WHERE a.session_id = s.id AND a.checkin_at IS NOT NULL) AS checked_in,
              (SELECT COUNT(*)::int FROM attendances a WHERE a.session_id = s.id
                  AND a.attendance_status IN ('CONFIRMED_PASS','CONFIRMED_FAIL','ABSENT')) AS reviewed
         FROM sessions s
         JOIN branches b ON b.id = s.branch_id
         LEFT JOIN classes c ON c.id = s.class_id
         LEFT JOIN lesson_plans lp ON lp.id = s.lesson_plan_id
        WHERE s.coach_id = $1 AND s.starts_at >= $2 AND s.starts_at < $3
        ORDER BY s.starts_at, s.id`,
      [coachId, from, to, env.APP_TIMEZONE],
    );
  }

  /** Null unless the session exists and belongs to the coach (callers answer 404 so other coaches' sessions never leak). */
  ownSession(coachId: string, sessionId: string): Promise<{ id: string } | null> {
    return sql.one(`SELECT id FROM sessions WHERE id = $1 AND coach_id = $2`, [sessionId, coachId]);
  }

  roster(sessionId: string): Promise<RosterRow[]> {
    return sql.many(
      `SELECT m.user_id AS member_id, m.member_code, u.full_name, u.avatar_url, r.rank_order, r.name_en AS rank_name,
              m.home_branch_id IS DISTINCT FROM s.branch_id AS other_branch,
              a.attendance_status, a.checkin_at, a.completion_percent, a.dp_awarded, a.coach_note, a.academy_result
         FROM sessions s
         JOIN LATERAL (${rosterIds('$2')}) ids ON true
         JOIN members m ON m.user_id = ids.member_id
         JOIN users u ON u.id = m.user_id
         LEFT JOIN ranks r ON r.id = m.current_rank_id
         LEFT JOIN attendances a ON a.session_id = s.id AND a.member_id = m.user_id
        WHERE s.id = $1
        ORDER BY u.full_name, m.user_id`,
      [sessionId, env.APP_TIMEZONE],
    );
  }
}
