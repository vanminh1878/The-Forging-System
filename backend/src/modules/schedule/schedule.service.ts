import { notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import {
  addDays,
  addMonthsToDate,
  localDate,
  monthStartOf,
  startOfLocalDay,
  weekStartOf,
} from '../../common/utils/time';
import type { ScheduleRepository, ScheduleRow } from './schedule.repository';
import { deriveStatus } from './schedule.rules';
import type { ScheduleStatus } from './schedule.rules';

export interface ScheduleQuery {
  view: 'week' | 'month';
  date?: string;
  branchId?: string;
  status?: ScheduleStatus;
}

function toItem(r: ScheduleRow, now: Date, today: string) {
  const date = localDate(r.startsAt);
  return {
    sessionId: r.sessionId,
    classId: r.classId,
    title: r.title,
    sessionType: r.sessionType,
    isExam: r.isExam,
    startsAt: r.startsAt,
    endsAt: r.endsAt,
    date,
    isToday: date === today,
    branch: { id: r.branchId, name: r.branchName },
    coach: { id: r.coachId, fullName: r.coachName },
    status: deriveStatus({ status: r.sessionStatus, endsAt: r.endsAt }, r.attendanceStatus, now),
    checkinAt: r.checkinAt,
    completionPercent: r.completionPercent,
  };
}

export class ScheduleService {
  constructor(private readonly repo: ScheduleRepository) {}

  async list(memberId: string, q: ScheduleQuery) {
    const now = clock.now();
    const today = localDate(now);
    const anchor = q.date ?? today;
    const from = q.view === 'week' ? weekStartOf(anchor) : monthStartOf(anchor);
    const to = q.view === 'week' ? addDays(from, 6) : addDays(addMonthsToDate(from, 1), -1);
    const rows = await this.repo.find(memberId, {
      from: startOfLocalDay(from),
      to: startOfLocalDay(addDays(to, 1)),
      branchId: q.branchId,
    });
    const items = rows.map((r) => toItem(r, now, today)).filter((i) => !q.status || i.status === q.status);
    return { items, meta: { view: q.view, from, to } };
  }

  /** 404 when the session is not on this learner's schedule, so other learners' sessions never leak. */
  async detail(memberId: string, sessionId: string) {
    const [row] = await this.repo.find(memberId, { sessionId });
    if (!row) throw notFound('Buổi tập');
    const now = clock.now();
    return {
      ...toItem(row, now, localDate(now)),
      lessonPlan: row.lessonPlanId ? { id: row.lessonPlanId, title: row.lessonPlanTitle } : null,
      notes: row.notes,
    };
  }
}
