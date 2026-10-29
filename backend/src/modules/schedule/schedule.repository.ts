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
}
