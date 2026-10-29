import { badRequest, conflict, notFound, unprocessable } from '../../common/errors/app-error';
import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import { addDays, daysBetween, isoWeekdayOf, localDate, startOfLocalDay, zonedToUtc } from '../../common/utils/time';
import { db } from '../../db/database';
import type { SessionCancelledEvent } from '../../shared/events';
import type { AuditService } from '../audit/audit.service';
import type { SettingsService } from '../settings/settings.service';
import type { ClassFilter, ClassRepository } from './class.repository';
import type { ClassInput, ClassRow, RosterEntry, SessionRow } from './class.types';

export interface EnrollInput {
  classId: string;
  memberId: string;
  startDate?: string;
  endDate?: string | null;
  membershipId?: string | null;
  by: string;
}

/** Does the session still match the class schedule (weekday, start time, duration)? Inactive classes match nothing. */
function fitsSchedule(cls: ClassRow, s: { startsAt: Date; endsAt: Date }): boolean {
  if (!cls.isActive) return false;
  const day = localDate(s.startsAt);
  return (
    cls.weekdays.includes(isoWeekdayOf(day)) &&
    zonedToUtc(day, cls.startTime).getTime() === s.startsAt.getTime() &&
    s.endsAt.getTime() - s.startsAt.getTime() === cls.durationMinutes * 60_000
  );
}

export class ClassService {
  constructor(
    private readonly repo: ClassRepository,
    private readonly audit: AuditService,
    private readonly settings: SettingsService,
  ) {}

  list(filter: ClassFilter, limit: number, offset: number) {
    return this.repo.list(filter, limit, offset);
  }

  async get(id: string): Promise<ClassRow & { enrolledCount: number; roster: RosterEntry[] }> {
    const cls = await this.repo.findById(id);
    if (!cls) throw notFound('Lớp học');
    const roster = await this.repo.roster(id);
    return { ...cls, enrolledCount: roster.length, roster };
  }

  async create(input: ClassInput, by: string): Promise<ClassRow> {
    await this.validateRefs(input);
    const row = await this.repo.insert(input);
    await this.audit.record({ actorId: by, action: 'CLASS_CREATED', entityType: 'CLASS', entityId: row.id, after: row });
    await this.syncSessions(row, null, by);
    return row;
  }

  async update(id: string, patch: Partial<ClassInput>, by: string): Promise<ClassRow> {
    const before = await this.repo.findById(id);
    if (!before) throw notFound('Lớp học');
    const next: ClassInput = { ...before, ...patch };
    await this.validateRefs(next, before);
    const row = await this.repo.update(id, next);
    await this.audit.record({ actorId: by, action: 'CLASS_UPDATED', entityType: 'CLASS', entityId: id, before, after: row });
    await this.syncSessions(row, before, by);
    return row;
  }

  /**
   * Creates the missing sessions for every active class (or one class) from today through the horizon.
   * Idempotent: (class, start) pairs that already exist are skipped. Returns the result lines for batch_runs.
   */
  async generateSessions(now: Date, classId?: string): Promise<string[]> {
    const lines: string[] = [];
    for (const cls of await this.repo.activeClasses(classId)) {
      if (!cls.defaultCoachId) {
        lines.push(`Lớp ${cls.name} chưa có coach mặc định — bỏ qua.`);
        continue;
      }
      const created = await this.generateFor(cls, cls.defaultCoachId, now);
      if (created > 0) lines.push(`Lớp ${cls.name}: +${created} buổi`);
    }
    return lines.length ? lines : ['Không có buổi mới cần sinh.'];
  }

  /** Inserts the class's sessions from now through the horizon (past start times today are not created). */
  private async generateFor(cls: ClassRow, coachId: string, now: Date): Promise<number> {
    const horizon = await this.settings.getNumber('classes.session_horizon_days');
    const today = localDate(now);
    const starts: Date[] = [];
    for (let i = 0; i <= horizon; i++) {
      const day = addDays(today, i);
      if (!cls.weekdays.includes(isoWeekdayOf(day))) continue;
      const startsAt = zonedToUtc(day, cls.startTime);
      if (startsAt >= now) starts.push(startsAt);
    }
    return starts.length ? this.repo.insertSessions(cls, coachId, starts) : 0;
  }

  /**
   * Brings a class's future sessions in line with its schedule (create, or update that changed the
   * schedule/coach/active flag): obsolete future sessions are deleted (nobody checked in) or cancelled
   * (someone did), the coach of the rest follows the class, then missing sessions are generated.
   */
  private async syncSessions(cls: ClassRow, before: ClassRow | null, by: string): Promise<void> {
    const now = clock.now();
    let deleted = 0;
    let cancelled = 0;
    let recoached = 0;
    if (before) {
      const same =
        before.isActive === cls.isActive &&
        before.startTime === cls.startTime &&
        before.durationMinutes === cls.durationMinutes &&
        before.defaultCoachId === cls.defaultCoachId &&
        before.weekdays.join() === cls.weekdays.join();
      if (same) return;
      const obsolete = (await this.repo.futureScheduledSessions(cls.id, now)).filter((s) => !fitsSchedule(cls, s));
      const drop = obsolete.filter((s) => !s.hasAttendance).map((s) => s.id);
      const cancel = obsolete.filter((s) => s.hasAttendance);
      if (drop.length) deleted = await this.repo.deleteSessions(drop);
      if (cancel.length) {
        cancelled = await this.repo.cancelSessions(cancel.map((s) => s.id));
        db.afterCommit(async () => {
          for (const s of cancel) {
            const event: SessionCancelledEvent = { sessionId: s.id, classId: cls.id, branchId: s.branchId, reason: 'Lớp đổi lịch', cancelledBy: by };
            await eventBus.emit(DomainEvents.SESSION_CANCELLED, event);
          }
        });
      }
      if (cls.isActive && cls.defaultCoachId && cls.defaultCoachId !== before.defaultCoachId) {
        recoached = await this.repo.setFutureCoach(cls.id, cls.defaultCoachId, now);
      }
    }
    const generated = cls.isActive && cls.defaultCoachId ? await this.generateFor(cls, cls.defaultCoachId, now) : 0;
    if (deleted || cancelled || recoached || generated) {
      await this.audit.record({
        actorId: by,
        action: 'CLASS_SESSIONS_SYNCED',
        entityType: 'CLASS',
        entityId: cls.id,
        after: { generated, deleted, cancelled, recoached },
      });
    }
  }

  /** Sessions of a class whose start falls in [from, to] (local dates, inclusive); defaults to the next horizon. */
  async listSessions(classId: string, from?: string, to?: string): Promise<SessionRow[]> {
    if (!(await this.repo.findById(classId))) throw notFound('Lớp học');
    const start = from ?? localDate(clock.now());
    const end = to ?? addDays(start, 28);
    if (end < start) throw badRequest('Ngày kết thúc phải sau ngày bắt đầu', undefined, 'INVALID_RANGE');
    if (daysBetween(start, end) > 92) throw badRequest('Khoảng thời gian tối đa 92 ngày', undefined, 'RANGE_TOO_LARGE');
    const rows = await this.repo.listSessions(classId, startOfLocalDay(start), startOfLocalDay(addDays(end, 1)));
    return rows.map((r) => ({ ...r, date: localDate(r.startsAt) }));
  }

  async enroll(input: EnrollInput): Promise<{ enrollmentId: string }> {
    // Lock the class row so two concurrent enrollments cannot both take the last seat.
    const cls = await this.repo.findById(input.classId, true);
    if (!cls) throw notFound('Lớp học');
    if (!cls.isActive) throw unprocessable('Lớp học đã ngừng hoạt động', 'CLASS_INACTIVE');
    const member = await this.repo.memberState(input.memberId);
    if (!member) throw notFound('Học viên');
    if (member.status === 'INACTIVE' || member.merged) {
      throw unprocessable('Tài khoản học viên không còn hoạt động', 'MEMBER_INACTIVE');
    }
    const startDate = input.startDate ?? localDate(clock.now());
    const endDate = input.endDate ?? null;
    if (endDate && endDate < startDate) throw badRequest('Ngày kết thúc phải sau ngày bắt đầu');
    if (input.membershipId && !(await this.repo.membershipBelongsTo(input.membershipId, input.memberId))) {
      throw badRequest('Gói tập không thuộc học viên này', undefined, 'MEMBERSHIP_NOT_FOUND');
    }
    if (await this.repo.hasActiveEnrollment(input.classId, input.memberId)) {
      throw conflict('Học viên đã có trong lớp này', 'ALREADY_ENROLLED');
    }
    if (cls.capacity !== null && (await this.repo.countActive(input.classId)) >= cls.capacity) {
      throw conflict('Lớp đã đủ sĩ số', 'CLASS_FULL');
    }
    const enrollmentId = await this.repo.insertEnrollment({
      classId: input.classId,
      memberId: input.memberId,
      membershipId: input.membershipId ?? null,
      startDate,
      endDate,
      by: input.by,
    });
    await this.audit.record({
      actorId: input.by,
      action: 'ROSTER_UPDATED',
      entityType: 'CLASS',
      entityId: input.classId,
      after: { op: 'ENROLL', memberId: input.memberId, enrollmentId, startDate, endDate },
    });
    return { enrollmentId };
  }

  async unenroll(classId: string, memberId: string, by: string, reason?: string): Promise<void> {
    const today = localDate(clock.now());
    const enrollmentId = await this.repo.endEnrollment(classId, memberId, today);
    if (!enrollmentId) throw notFound('Học viên trong lớp');
    await this.audit.record({
      actorId: by,
      action: 'ROSTER_UPDATED',
      entityType: 'CLASS',
      entityId: classId,
      after: { op: 'END', memberId, enrollmentId, endDate: today },
      reason: reason ?? null,
    });
  }

  /** `before` is set on update: unchanged refs (e.g. a since-deactivated branch) are not re-validated. */
  private async validateRefs(i: ClassInput, before?: ClassRow): Promise<void> {
    if (i.branchId !== before?.branchId && !(await this.repo.branchIsActive(i.branchId))) {
      throw unprocessable('Chi nhánh không tồn tại hoặc đã ngừng hoạt động', 'BRANCH_INACTIVE');
    }
    if (i.sessionTypeCode !== before?.sessionTypeCode && !(await this.repo.sessionTypeExists(i.sessionTypeCode))) {
      throw badRequest('Loại buổi tập không tồn tại', undefined, 'SESSION_TYPE_NOT_FOUND');
    }
    if (i.courseId && i.courseId !== before?.courseId && !(await this.repo.courseExists(i.courseId))) {
      throw badRequest('Khoá học không tồn tại', undefined, 'COURSE_NOT_FOUND');
    }
    if (i.defaultCoachId && i.defaultCoachId !== before?.defaultCoachId && !(await this.repo.isCoach(i.defaultCoachId))) {
      throw badRequest('Người dùng được chọn không phải huấn luyện viên', undefined, 'COACH_INVALID');
    }
  }
}
