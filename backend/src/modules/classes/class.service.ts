import { badRequest, conflict, notFound, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { localDate } from '../../common/utils/time';
import type { AuditService } from '../audit/audit.service';
import type { ClassFilter, ClassRepository } from './class.repository';
import type { ClassInput, ClassRow, RosterEntry } from './class.types';

export interface EnrollInput {
  classId: string;
  memberId: string;
  startDate?: string;
  endDate?: string | null;
  membershipId?: string | null;
  by: string;
}

export class ClassService {
  constructor(
    private readonly repo: ClassRepository,
    private readonly audit: AuditService,
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
    return row;
  }

  async update(id: string, patch: Partial<ClassInput>, by: string): Promise<ClassRow> {
    const before = await this.repo.findById(id);
    if (!before) throw notFound('Lớp học');
    const next: ClassInput = { ...before, ...patch };
    await this.validateRefs(next, before);
    const row = await this.repo.update(id, next);
    await this.audit.record({ actorId: by, action: 'CLASS_UPDATED', entityType: 'CLASS', entityId: id, before, after: row });
    return row;
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
