import { badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import { env } from '../../config/env';
import { addDays, daysBetween, isoWeekdayOf, localDate, startOfLocalDay, zonedParts, zonedToUtc } from '../../common/utils/time';
import { db } from '../../db/database';
import type { SessionCancelledEvent } from '../../shared/events';
import { RoleGroup } from '../../shared/roles';
import type { RoleCode } from '../../shared/roles';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { AuditService } from '../audit/audit.service';
import type { SettingsService } from '../settings/settings.service';
import type { ClassFilter, ClassRepository } from './class.repository';
import type { ClassInput, ClassRow, RosterEntry, SessionRecord, SessionRow } from './class.types';

export interface EnrollInput {
  classId: string;
  memberId: string;
  startDate?: string;
  endDate?: string | null;
  membershipId?: string | null;
  by: string;
}

export interface Actor {
  userId: string;
  roles: readonly RoleCode[];
}

export interface OneOffSessionInput {
  sessionTypeCode: string;
  branchId: string;
  startsAt: Date;
  durationMinutes: number;
  title: string;
  coachId?: string;
  classId?: string;
  lessonPlanId?: string;
  isExam?: boolean;
  capacity?: number;
  maxDpOverride?: number;
  notes?: string;
  memberIds?: string[];
}

const NOT_YOURS = 'Bạn chỉ được thao tác buổi/lớp mình phụ trách.';
const pad2 = (n: number) => String(n).padStart(2, '0');
/** "HH:mm dd/MM/yyyy" in the tenant timezone. */
function fmtWhen(d: Date): string {
  const p = zonedParts(d);
  return `${pad2(p.hour)}:${pad2(p.minute)} ${pad2(p.day)}/${pad2(p.month)}/${p.year}`;
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
    private readonly notifier: NotifierPort,
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

  private isAdmin(actor: Actor): boolean {
    return actor.roles.some((r) => (RoleGroup.ADMINS as readonly string[]).includes(r));
  }

  /** POST /sessions: a one-off session (PT, Academy, workshop...), optionally with hand-picked learners. */
  async createSession(input: OneOffSessionInput, actor: Actor): Promise<SessionRecord & { attendeeCount: number }> {
    const admin = this.isAdmin(actor);
    const coachId = input.coachId ?? actor.userId;
    if (!admin && coachId !== actor.userId) throw forbidden(NOT_YOURS, 'NOT_YOUR_SESSION');
    const type = await this.repo.sessionType(input.sessionTypeCode);
    if (!type) throw unprocessable('Loại buổi tập không tồn tại hoặc đã tắt', 'SESSION_TYPE_INACTIVE');
    if (!(await this.repo.branchIsActive(input.branchId))) {
      throw unprocessable('Chi nhánh không tồn tại hoặc đã ngừng hoạt động', 'BRANCH_INACTIVE');
    }
    if (input.startsAt.getTime() <= clock.now().getTime()) {
      throw unprocessable('Không thể tạo buổi trong quá khứ.', 'SESSION_IN_PAST');
    }
    if (input.maxDpOverride !== undefined) {
      if (type.maxDpUpper === null || input.maxDpOverride < type.maxDp || input.maxDpOverride > type.maxDpUpper) {
        const range = type.maxDpUpper === null ? `${type.maxDp}–${type.maxDp}` : `${type.maxDp}–${type.maxDpUpper}`;
        throw unprocessable(`DP tối đa phải trong khoảng ${range}.`, 'MAX_DP_OUT_OF_RANGE');
      }
    }
    if (coachId !== actor.userId && !(await this.repo.isCoach(coachId))) {
      throw badRequest('Người dùng được chọn không phải huấn luyện viên', undefined, 'COACH_INVALID');
    }
    if (input.classId && !(await this.repo.findById(input.classId))) throw notFound('Lớp học');
    if (input.lessonPlanId && !(await this.repo.lessonPlanExists(input.lessonPlanId))) {
      throw badRequest('Giáo án không tồn tại', undefined, 'LESSON_PLAN_NOT_FOUND');
    }
    const memberIds = [...new Set(input.memberIds ?? [])];
    if (memberIds.length && (await this.repo.countMembers(memberIds)) !== memberIds.length) {
      throw badRequest('Có học viên không tồn tại', undefined, 'MEMBER_NOT_FOUND');
    }
    const endsAt = new Date(input.startsAt.getTime() + input.durationMinutes * 60_000);
    if (input.classId && (await this.repo.classSessionAt(input.classId, input.startsAt))) {
      throw conflict('Lớp đã có buổi vào giờ này.', 'SESSION_ALREADY_EXISTS');
    }
    if (await this.repo.coachBusy(coachId, input.startsAt, endsAt)) {
      throw conflict('Coach đã có buổi khác trùng giờ.', 'COACH_SESSION_OVERLAP');
    }
    const row = await this.repo.insertSession({
      classId: input.classId ?? null,
      branchId: input.branchId,
      sessionTypeCode: input.sessionTypeCode,
      coachId,
      lessonPlanId: input.lessonPlanId ?? null,
      title: input.title,
      startsAt: input.startsAt,
      endsAt,
      maxDpOverride: input.maxDpOverride ?? null,
      isExam: input.isExam ?? false,
      capacity: input.capacity ?? null,
      notes: input.notes ?? null,
      createdBy: actor.userId,
    });
    if (memberIds.length) await this.repo.addAttendances(row.id, memberIds);
    await this.audit.record({
      actorId: actor.userId,
      action: 'SESSION_CREATED',
      entityType: 'SESSION',
      entityId: row.id,
      after: { ...row, memberIds },
    });
    return { ...row, attendeeCount: memberIds.length };
  }

  /** POST /classes/:id/exam-sessions: turns the class's session on that date into an exam, or creates one. */
  async createExamSession(
    classId: string,
    input: { date: string; title?: string; lessonPlanId?: string },
    actor: Actor,
  ): Promise<SessionRecord> {
    const cls = await this.repo.findById(classId);
    if (!cls) throw notFound('Lớp học');
    const admin = this.isAdmin(actor);
    if (!admin && cls.defaultCoachId !== actor.userId) throw forbidden(NOT_YOURS, 'NOT_YOUR_SESSION');
    if (!cls.isActive) throw unprocessable('Lớp học đã ngừng hoạt động', 'CLASS_INACTIVE');
    const startsAt = zonedToUtc(input.date, cls.startTime);
    if (startsAt.getTime() <= clock.now().getTime()) {
      throw unprocessable('Không thể tạo buổi trong quá khứ.', 'SESSION_IN_PAST');
    }
    if (input.lessonPlanId && !(await this.repo.lessonPlanExists(input.lessonPlanId))) {
      throw badRequest('Giáo án không tồn tại', undefined, 'LESSON_PLAN_NOT_FOUND');
    }
    const title = input.title ?? `Kiểm tra — ${cls.name}`;
    const lessonPlanId = input.lessonPlanId ?? null;
    const existing = await this.repo.classSessionAt(classId, startsAt);
    let row: SessionRecord;
    if (existing) {
      if (existing.status !== 'SCHEDULED') throw conflict('Buổi này đã bắt đầu hoặc kết thúc.', 'SESSION_ALREADY_EXISTS');
      row = (await this.repo.markExam(existing.id, title, lessonPlanId)) as SessionRecord;
    } else {
      const coachId = cls.defaultCoachId ?? actor.userId;
      const endsAt = new Date(startsAt.getTime() + cls.durationMinutes * 60_000);
      if (await this.repo.coachBusy(coachId, startsAt, endsAt)) {
        throw conflict('Coach đã có buổi khác trùng giờ.', 'COACH_SESSION_OVERLAP');
      }
      row = await this.repo.insertSession({
        classId,
        branchId: cls.branchId,
        sessionTypeCode: cls.sessionTypeCode,
        coachId,
        lessonPlanId,
        title,
        startsAt,
        endsAt,
        maxDpOverride: null,
        isExam: true,
        capacity: cls.capacity,
        notes: null,
        createdBy: actor.userId,
      });
    }
    const d = input.date.split('-');
    await this.audit.record({
      actorId: actor.userId,
      action: 'EXAM_CREATED',
      entityType: 'SESSION',
      entityId: row.id,
      after: row,
      reason: `${cls.name} · ${d[2]}/${d[1]}/${d[0]}`,
    });
    for (const memberId of await this.repo.sessionRecipients(row.id, env.APP_TIMEZONE)) {
      await this.notifier.notifyMember({
        userId: memberId,
        event: NotificationEvent.EXAM,
        title: 'BUỔI KIỂM TRA MỚI',
        body: `${title} — ${d[2]}/${d[1]}/${d[0]} ${fmtWhen(startsAt).slice(0, 5)}.`,
        payload: { sessionId: row.id },
        dedupeKey: `exam:${row.id}:${memberId}`,
      });
    }
    return row;
  }

  /** POST /sessions/:id/cancel: keeps the row as CANCELLED (the generator will not recreate it) and tells the learners. */
  async cancelSession(sessionId: string, reason: string | undefined, actor: Actor): Promise<SessionRecord> {
    const text = reason?.trim();
    if (!text) throw badRequest('Vui lòng nhập lý do huỷ.', undefined, 'CANCEL_REASON_REQUIRED');
    const s = await this.repo.findSession(sessionId, true);
    if (!s) throw notFound('Buổi tập');
    if (!this.isAdmin(actor) && s.coachId !== actor.userId) {
      const cls = s.classId ? await this.repo.findById(s.classId) : null;
      if (cls?.defaultCoachId !== actor.userId) throw forbidden(NOT_YOURS, 'NOT_YOUR_SESSION');
    }
    if (s.status !== 'SCHEDULED' || s.startsAt.getTime() <= clock.now().getTime()) {
      throw conflict('Chỉ huỷ được buổi chưa diễn ra.', 'SESSION_NOT_CANCELLABLE');
    }
    await this.repo.cancelSession(sessionId);
    const row = { ...s, status: 'CANCELLED' };
    await this.audit.record({
      actorId: actor.userId,
      action: 'SESSION_CANCELLED',
      entityType: 'SESSION',
      entityId: sessionId,
      before: s,
      after: row,
      reason: text,
    });
    const when = fmtWhen(s.startsAt);
    const [time, day] = when.split(' ');
    for (const memberId of await this.repo.sessionRecipients(sessionId, env.APP_TIMEZONE)) {
      await this.notifier.notifyMember({
        userId: memberId,
        event: NotificationEvent.SESSION_CANCELLED,
        title: 'BUỔI TẬP BỊ HUỶ',
        body: `${s.title ?? 'Buổi tập'} ${time} ${day.slice(0, 5)} đã huỷ. Lý do: ${text}.`,
        payload: { sessionId },
        dedupeKey: `session-cancelled:${sessionId}:${memberId}`,
      });
    }
    db.afterCommit(async () => {
      const event: SessionCancelledEvent = { sessionId, classId: s.classId, branchId: s.branchId, reason: text, cancelledBy: actor.userId };
      await eventBus.emit(DomainEvents.SESSION_CANCELLED, event);
    });
    return row;
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
