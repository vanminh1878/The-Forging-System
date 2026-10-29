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
import type { CoachSessionRow, RosterRow, ScheduleRepository, ScheduleRow } from './schedule.repository';
import { deriveStatus } from './schedule.rules';
import type { ScheduleStatus } from './schedule.rules';

export interface ScheduleQuery {
  view: 'week' | 'month';
  date?: string;
  branchId?: string;
  status?: ScheduleStatus;
}

const REVIEWED = new Set(['CONFIRMED_PASS', 'CONFIRMED_FAIL', 'ABSENT']);

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

  // ---- coach side (CLS-05) ----

  async coachClasses(coachId: string) {
    const rows = await this.repo.coachClasses(coachId);
    return rows.map((c) => ({
      id: c.id,
      name: c.name,
      branch: { id: c.branchId, name: c.branchName },
      sessionType: c.sessionType,
      weekdays: c.weekdays,
      startTime: c.startTime,
      durationMinutes: c.durationMinutes,
      enrolledCount: c.enrolledCount,
    }));
  }

  /** The coach's own sessions for a day or a Monday..Sunday week. */
  async coachSessions(coachId: string, q: { view: 'day' | 'week'; date?: string }) {
    const today = localDate(clock.now());
    const anchor = q.date ?? today;
    const from = q.view === 'week' ? weekStartOf(anchor) : anchor;
    const to = q.view === 'week' ? addDays(from, 6) : anchor;
    const rows = await this.repo.coachSessions(coachId, startOfLocalDay(from), startOfLocalDay(addDays(to, 1)));
    const items = rows.map((r: CoachSessionRow) => {
      const date = localDate(r.startsAt);
      return {
        sessionId: r.sessionId,
        classId: r.classId,
        className: r.className,
        title: r.title,
        sessionType: r.sessionType,
        isExam: r.isExam,
        status: r.status,
        startsAt: r.startsAt,
        endsAt: r.endsAt,
        date,
        isToday: date === today,
        branch: { id: r.branchId, name: r.branchName },
        lessonPlan: r.lessonPlanId ? { id: r.lessonPlanId, title: r.lessonPlanTitle } : null,
        counts: { registered: r.registered, checkedIn: r.checkedIn, reviewed: r.reviewed },
      };
    });
    return { items, meta: { view: q.view, from, to } };
  }

  /** 404 when the session is not the coach's own. */
  async coachRoster(coachId: string, sessionId: string, filter: 'all' | 'pending' | 'reviewed') {
    if (!(await this.repo.ownSession(coachId, sessionId))) throw notFound('Buổi tập');
    const all = (await this.repo.roster(sessionId)).map((r: RosterRow) => ({
      memberId: r.memberId,
      memberCode: r.memberCode,
      fullName: r.fullName,
      avatarUrl: r.avatarUrl,
      rank: r.rankOrder === null ? null : { order: r.rankOrder, name: r.rankName },
      otherBranch: r.otherBranch,
      status: r.attendanceStatus ?? 'UPCOMING',
      checkinAt: r.checkinAt,
      completionPercent: r.completionPercent,
      dpAwarded: r.dpAwarded ?? 0,
      coachNote: r.coachNote,
      academyResult: r.academyResult,
    }));
    const reviewed = all.filter((r) => REVIEWED.has(r.status));
    const counts = { all: all.length, pending: all.length - reviewed.length, reviewed: reviewed.length };
    const items = filter === 'all' ? all : filter === 'reviewed' ? reviewed : all.filter((r) => !REVIEWED.has(r.status));
    return { items, meta: { counts } };
  }
}
