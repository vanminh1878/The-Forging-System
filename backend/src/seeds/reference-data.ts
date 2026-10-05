import { db } from '../db/database';
import { sql } from '../db/sql';
import { DEFAULT_TEMPLATES } from '../modules/notifications/notification.events';
import { buildLessons, COURSES, PACKAGES, RANK_COURSE_GATES } from './curriculum';

/**
 * Idempotent reference data every tenant needs: courses + lesson plans,
 * packages, rank course gates and notification templates. Safe to re-run.
 * Roles, ranks, session types and reward tiers already ship with migration 0001.
 */
export async function seedReferenceData(tenantId: string): Promise<void> {
  await db.tenantTx(tenantId, async () => {
    const courseIds = new Map<string, string>();

    for (const course of COURSES) {
      const row = await sql.one<{ id: string }>(
        `INSERT INTO courses (tenant_id, code, name, duration_weeks, total_lessons, description)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (tenant_id, code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description
         RETURNING id`,
        [tenantId, course.code, course.name, course.weeks.length, course.weeks.length * 3, course.goal],
      );
      courseIds.set(course.code, row!.id);
      for (const l of buildLessons(course)) {
        await sql.exec(
          `INSERT INTO lesson_plans (tenant_id, course_id, lesson_no, week_no, title, subtitle, objectives, content, is_assessment, is_graduation)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10)
           ON CONFLICT (course_id, lesson_no) DO NOTHING`,
          [tenantId, row!.id, l.lessonNo, l.weekNo, l.title, l.subtitle, l.objectives, JSON.stringify({ drills: l.drills }), l.isAssessment, l.isGraduation],
        );
      }
    }

    for (const p of PACKAGES) {
      await sql.exec(
        `INSERT INTO package_types (tenant_id, code, name, duration_days, total_sessions, sessions_per_week, is_trial,
                                    unlocks_course_id, max_rank_order, price_vnd, sort_order)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         ON CONFLICT (tenant_id, code) DO NOTHING`,
        [tenantId, p.code, p.name, p.durationDays, p.totalSessions, p.sessionsPerWeek, p.isTrial, p.courseCode ? courseIds.get(p.courseCode)! : null, p.isTrial ? 2 : null, p.priceVnd, p.sortOrder],
      );
    }

    for (const [order, codes] of Object.entries(RANK_COURSE_GATES)) {
      for (const code of codes) {
        await sql.exec(
          `INSERT INTO rank_required_courses (tenant_id, rank_id, course_id)
           SELECT $1, r.id, $3 FROM ranks r WHERE r.rank_order = $2
           ON CONFLICT DO NOTHING`,
          [tenantId, Number(order), courseIds.get(code)!],
        );
      }
    }

    for (const t of DEFAULT_TEMPLATES) {
      await sql.exec(
        `INSERT INTO notification_templates (tenant_id, event_type, title, body)
         VALUES ($1,$2,$3,$4) ON CONFLICT (tenant_id, event_type) DO NOTHING`,
        [tenantId, t.event, t.title, t.body],
      );
    }
  });
}
