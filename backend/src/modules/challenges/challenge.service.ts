import { badRequest, conflict, notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { localDate, monthStartOf, startOfLocalDay } from '../../common/utils/time';
import { env } from '../../config/env';
import type { AuditService } from '../audit/audit.service';
import type { PointsPort } from '../points/points.service';
import type { SettingsService } from '../settings/settings.service';
import type { NotifierPort } from '../notifications/notification.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { AttendanceConfirmedEvent } from '../../shared/events';
import type {
  ChallengeParticipationView,
  ChallengeRepository,
  ChallengeView,
  ChallengeWrite,
  OpenChallengeView,
} from './challenge.repository';
import type {
  ChallengeEnabledInput,
  ChallengeEvidenceInput,
  ChallengeFilter,
  CreateChallengeInput,
  OpenChallengeFilter,
  StaffParticipationFilter,
  UpdateChallengeInput,
} from './challenge.validation';

const ruleFields = [
  'challengeType',
  'context',
  'target',
  'rewardDp',
  'rewardMarks',
  'startsAt',
  'endsAt',
] as const;

export class ChallengeService {
  constructor(
    private readonly repo: ChallengeRepository,
    private readonly audit: AuditService,
    private readonly points?: PointsPort,
    private readonly settings?: SettingsService,
    private readonly notifier?: NotifierPort,
  ) {}

  search(filter: ChallengeFilter, limit: number, offset: number) {
    return this.repo.search(filter, limit, offset);
  }

  staffParticipations(filter: StaffParticipationFilter, limit: number, offset: number) {
    return this.repo.staffParticipations(filter, limit, offset);
  }

  async get(id: string): Promise<ChallengeView> {
    const challenge = await this.repo.find(id);
    if (!challenge) throw notFound('Challenge');
    return challenge;
  }

  async listOpenForMember(
    memberId: string,
    filter: OpenChallengeFilter,
    limit: number,
    offset: number,
  ): Promise<{ items: OpenChallengeView[]; total: number }> {
    const challengeType = filter.challengeType ?? filter.period ?? null;
    return this.repo.listOpenForMember(
      memberId,
      challengeType,
      filter.context ?? null,
      filter.q ?? null,
      clock.now(),
      limit,
      offset,
    );
  }

  async join(memberId: string, challengeId: string): Promise<ChallengeParticipationView> {
    const challenge = await this.repo.find(challengeId, true);
    if (!challenge) throw notFound('Challenge');
    if (challenge.status !== 'OPEN') throw conflict('Thu thach chua mo hoac da dong.', 'CHALLENGE_NOT_OPEN');
    const now = clock.now();
    if (now < challenge.startsAt || now >= challenge.endsAt) {
      throw conflict('Thu thach khong trong thoi gian tham gia.', 'CHALLENGE_CLOSED');
    }
    const existing = await this.repo.findParticipation(challengeId, memberId);
    if (existing) throw conflict('Ban da tham gia thu thach nay.', 'CHALLENGE_ALREADY_JOINED');
    const participation = await this.repo.insertParticipation(challengeId, memberId);
    await this.audit.record({
      actorId: memberId,
      action: 'CHALLENGE_JOINED',
      entityType: 'CHALLENGE',
      entityId: challengeId,
      after: participation,
    });
    await this.notifier?.notifyMember({
      userId: memberId,
      event: NotificationEvent.CHALLENGE_JOINED,
      title: 'ĐÃ GỬI ĐĂNG KÝ THỬ THÁCH',
      body: `Bạn đã đăng ký “${challenge.title}”. Chờ Coach duyệt tham gia.`,
      dedupeKey: `challenge:joined:${participation.id}`,
      payload: { challengeId: challenge.id, participationId: participation.id },
    });
    await this.notifier?.notifyStaff(
      'COACH',
      NotificationEvent.CHALLENGE_EVIDENCE,
      'ĐĂNG KÝ THỬ THÁCH MỚI',
      `Có học viên đăng ký “${challenge.title}”. Mở tab Challenge để duyệt tham gia.`,
    );
    return participation;
  }

  /** Coach accepts a member's Challenge registration before the member can submit completion evidence. */
  async approveJoin(participationId: string, actorId: string): Promise<ChallengeParticipationView> {
    const before = await this.repo.findParticipationById(participationId, true);
    if (!before) throw notFound('Challenge participation');
    if (before.status !== 'PENDING_COACH') {
      throw conflict('Đăng ký thử thách không còn chờ Coach duyệt.', 'CHALLENGE_NOT_PENDING_JOIN');
    }
    const after = await this.repo.approveJoin(before.id, actorId, clock.now());
    const challenge = await this.repo.find(before.challengeId);
    await this.audit.record({
      actorId,
      action: 'CHALLENGE_JOIN_APPROVED',
      entityType: 'CHALLENGE_PARTICIPATION',
      entityId: after.id,
      before,
      after,
    });
    await this.notifier?.notifyMember({
      userId: after.memberId,
      event: NotificationEvent.CHALLENGE_JOIN_APPROVED,
      title: 'ĐĂNG KÝ THỬ THÁCH ĐÃ ĐƯỢC DUYỆT',
      body: `Coach đã duyệt “${challenge?.title ?? 'thử thách'}”. Khi hoàn thành, hãy gửi yêu cầu hoàn thành kèm bằng chứng.`,
      dedupeKey: `challenge:join-approved:${after.id}`,
      payload: { challengeId: after.challengeId, participationId: after.id },
    });
    return after;
  }

  /** CHL-05: advances joined challenges after a coach confirms attendance. */
  async recordConfirmedAttendance(event: AttendanceConfirmedEvent): Promise<void> {
    const context = event.isExam
      ? 'EXAM'
      : event.sessionType.toUpperCase() === 'WORKSHOP'
        ? 'WORKSHOP'
        : 'SESSION';
    const updates = await this.repo.recordAttendanceProgress(
      event.memberId,
      event.attendanceId,
      context,
      clock.now(),
    );
    for (const { participation, target } of updates) {
      await this.audit.record({
        actorId: event.confirmedBy,
        action:
          participation.status === 'AWAITING_COACH'
            ? 'CHALLENGE_TARGET_REACHED'
            : 'CHALLENGE_PROGRESS_UPDATED',
        entityType: 'CHALLENGE_PARTICIPATION',
        entityId: participation.id,
        after: { ...participation, target, source: 'ATTENDANCE_CONFIRMED', attendanceId: event.attendanceId },
      });
      if (participation.status === 'AWAITING_COACH' && this.notifier) {
        const challenge = await this.repo.find(participation.challengeId);
        await this.notifier.notifyMember({
          userId: participation.memberId,
          event: NotificationEvent.CHALLENGE_COMPLETED,
          title: 'HOÀN THÀNH THỬ THÁCH',
          body: `Bạn đã hoàn thành “${challenge?.title ?? 'thử thách'}”. Hãy nộp bằng chứng để Coach duyệt phần thưởng.`,
          dedupeKey: `challenge:completed:${participation.id}`,
          payload: { challengeId: participation.challengeId, participationId: participation.id },
        });
      }
    }
  }

  /** Member requests completion by attaching proof after Coach approved their registration. */
  async submitEvidence(
    memberId: string,
    challengeId: string,
    input: ChallengeEvidenceInput,
  ): Promise<ChallengeParticipationView> {
    const participation = await this.repo.findParticipation(challengeId, memberId, true);
    if (!participation) throw notFound('Challenge participation');
    if (participation.status !== 'JOINED') {
      throw conflict(
        'Chỉ gửi yêu cầu hoàn thành sau khi Coach duyệt đăng ký thử thách.',
        'CHALLENGE_NOT_JOINED',
      );
    }
    const evidenceUrl = this.requireEvidence(input.evidenceUrl);
    if (participation.evidenceUrl === evidenceUrl) return participation;
    const after = await this.repo.submitCompletionEvidence(participation.id, evidenceUrl, clock.now());
    await this.audit.record({
      actorId: memberId,
      action: 'CHALLENGE_EVIDENCE_SUBMITTED',
      entityType: 'CHALLENGE_PARTICIPATION',
      entityId: after.id,
      before: participation,
      after,
    });
    const challenge = await this.repo.find(participation.challengeId);
    await this.notifier?.notifyStaff(
      'COACH',
      NotificationEvent.CHALLENGE_EVIDENCE,
      'BẰNG CHỨNG CHALLENGE MỚI',
      `Có bằng chứng mới cho “${challenge?.title ?? 'Challenge'}”. Mở tab Challenge để duyệt và phát thưởng.`,
    );
    return after;
  }

  /** CHL-06: coaching staff confirms proof and posts the configured reward once. */
  async approveEvidence(
    participationId: string,
    actorId: string,
  ): Promise<{ participation: ChallengeParticipationView; duplicate: boolean }> {
    const participation = await this.repo.findParticipationById(participationId, true);
    if (!participation) throw notFound('Challenge participation');
    if (participation.status === 'REWARDED') return { participation, duplicate: true };
    if (participation.status !== 'AWAITING_COACH') {
      throw conflict('Participation chưa sẵn sàng để Coach duyệt.', 'CHALLENGE_NOT_AWAITING_REVIEW');
    }
    if (!participation.evidenceUrl)
      throw conflict('Học viên chưa nộp bằng chứng.', 'CHALLENGE_EVIDENCE_REQUIRED');
    const challenge = await this.repo.find(participation.challengeId, true);
    if (!challenge) throw notFound('Challenge');

    if (!this.points || !this.settings) throw new Error('Challenge reward dependencies are not configured.');
    const now = clock.now();
    await this.repo.lockMember(participation.memberId);
    const limit = await this.settings.getNumber('challenge.monthly_reward_limit');
    const used = await this.repo.rewardedThisMonth(
      participation.memberId,
      startOfLocalDay(monthStartOf(localDate(now))),
    );
    const isLimited = used >= limit;
    if (!isLimited) {
      await this.points.award({
        memberId: participation.memberId,
        source: 'CHALLENGE',
        dp: challenge.rewardDp,
        marks: challenge.rewardMarks,
        note: `Challenge completed: ${challenge.title}`,
        by: actorId,
        challengeParticipationId: participation.id,
        idempotencyKey: `challenge:reward:${participation.id}`,
      });
    }
    const after = await this.repo.approveParticipation(participation.id, actorId, now, isLimited);
    await this.notifier?.notifyMember({
      userId: participation.memberId,
      event: NotificationEvent.CHALLENGE_REWARDED,
      title: isLimited ? 'THỬ THÁCH ĐÃ ĐƯỢC DUYỆT' : 'PHẦN THƯỞNG THỬ THÁCH ĐÃ VỀ',
      body: isLimited
        ? `Coach đã duyệt “${challenge.title}”. Bạn đã đạt giới hạn phần thưởng Challenge trong tháng này.`
        : `Coach đã duyệt “${challenge.title}”. Bạn nhận ${challenge.rewardDp} DP và ${challenge.rewardMarks} Marks.`,
      dedupeKey: `challenge:rewarded:${participation.id}`,
      payload: { challengeId: challenge.id, participationId: participation.id },
    });
    await this.audit.record({
      actorId,
      action: isLimited ? 'CHALLENGE_APPROVED_LIMITED' : 'CHALLENGE_APPROVED',
      entityType: 'CHALLENGE_PARTICIPATION',
      entityId: after.id,
      before: participation,
      after,
    });
    return { participation: after, duplicate: false };
  }

  async create(input: CreateChallengeInput, actorId: string): Promise<ChallengeView> {
    const data = { ...input, startsAt: new Date(input.startsAt), endsAt: new Date(input.endsAt) };
    this.validateDates(data);
    await this.ensureUniqueCode(data.code);
    const after = await this.repo.create(data, actorId);
    await this.audit.record({
      actorId,
      action: 'CHALLENGE_CREATED',
      entityType: 'CHALLENGE',
      entityId: after.id,
      after,
    });
    return after;
  }

  async update(id: string, input: UpdateChallengeInput, actorId: string): Promise<ChallengeView> {
    const before = await this.repo.find(id, true);
    if (!before) throw notFound('Challenge');
    if (before.status === 'CANCELLED')
      throw conflict('Thử thách đã bị hủy, không thể chỉnh sửa.', 'CHALLENGE_CANCELLED');
    const { reason, ...patch } = input;
    const after: ChallengeWrite = {
      code: patch.code === undefined ? before.code : patch.code,
      title: patch.title ?? before.title,
      description: patch.description === undefined ? before.description : patch.description,
      challengeType: patch.challengeType ?? before.challengeType,
      context: patch.context ?? before.context,
      target: patch.target ?? before.target,
      rewardDp: patch.rewardDp ?? before.rewardDp,
      rewardMarks: patch.rewardMarks ?? before.rewardMarks,
      startsAt: patch.startsAt === undefined ? before.startsAt : new Date(patch.startsAt),
      endsAt: patch.endsAt === undefined ? before.endsAt : new Date(patch.endsAt),
    };
    this.validateDates(after);
    if (
      ruleFields.some((field) => !this.equal(before[field], after[field])) &&
      (await this.repo.hasParticipants(id))
    ) {
      throw conflict(
        'Không thể sửa điều kiện, phần thưởng hoặc thời gian khi đã có học viên tham gia.',
        'CHALLENGE_RULES_LOCKED',
      );
    }
    await this.ensureUniqueCode(after.code, id);
    if (Object.entries(after).every(([key, value]) => this.equal(before[key as keyof ChallengeWrite], value)))
      return before;
    const saved = await this.repo.update(id, after);
    await this.audit.record({
      actorId,
      action: 'CHALLENGE_UPDATED',
      entityType: 'CHALLENGE',
      entityId: id,
      before,
      after: saved,
      reason,
    });
    return saved;
  }

  /** Publishes/closes the catalogue entry without deciding any learner's participation. */
  async setEnabled(
    id: string,
    input: ChallengeEnabledInput,
    actorId: string,
  ): Promise<ChallengeView & { enabled: boolean }> {
    const before = await this.repo.find(id, true);
    if (!before) throw notFound('Challenge');
    if (input.enabled) {
      if (before.status === 'CANCELLED')
        throw conflict('Thử thách đã bị hủy, không thể mở lại.', 'CHALLENGE_CANCELLED');
      this.validateDates(before);
      if (before.endsAt.getTime() <= clock.now().getTime()) {
        throw conflict('Thử thách đã hết hạn, không thể bật.', 'CHALLENGE_EXPIRED');
      }
      if (
        !Number.isInteger(before.target) ||
        before.target < 1 ||
        !Number.isInteger(before.rewardDp) ||
        before.rewardDp < 0 ||
        !Number.isInteger(before.rewardMarks) ||
        before.rewardMarks < 0
      ) {
        throw badRequest(
          'Mục tiêu và phần thưởng thử thách không hợp lệ.',
          undefined,
          'INVALID_CHALLENGE_CONFIG',
        );
      }
    }
    // Disabling a draft/cancelled/already-closed entry must not implicitly publish or revive it.
    if ((input.enabled && before.status === 'OPEN') || (!input.enabled && before.status !== 'OPEN')) {
      return { ...before, enabled: before.status === 'OPEN' };
    }
    const after = await this.repo.setStatus(id, input.enabled ? 'OPEN' : 'CLOSED');
    await this.audit.record({
      actorId,
      action: input.enabled ? 'CHALLENGE_ENABLED' : 'CHALLENGE_DISABLED',
      entityType: 'CHALLENGE',
      entityId: id,
      before,
      after,
      reason: input.reason,
    });
    return { ...after, enabled: after.status === 'OPEN' };
  }

  private validateDates(input: ChallengeWrite) {
    if (
      !Number.isFinite(input.startsAt.getTime()) ||
      !Number.isFinite(input.endsAt.getTime()) ||
      input.startsAt >= input.endsAt
    ) {
      throw badRequest(
        'Thời gian kết thúc phải sau thời gian bắt đầu.',
        undefined,
        'INVALID_CHALLENGE_DATES',
      );
    }
  }

  private requireEvidence(url: string): string {
    const value = url.trim();
    if (!value.startsWith(`${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/`)) {
      throw badRequest(
        'Bằng chứng phải là file do hệ thống tải lên.',
        undefined,
        'INVALID_CHALLENGE_EVIDENCE',
      );
    }
    return value;
  }

  private async ensureUniqueCode(code: string | null, exceptId?: string) {
    if (code && (await this.repo.codeExists(code, exceptId)))
      throw conflict('Mã thử thách đã được sử dụng.', 'CHALLENGE_CODE_TAKEN');
  }

  private equal(a: unknown, b: unknown): boolean {
    return a instanceof Date && b instanceof Date ? a.getTime() === b.getTime() : a === b;
  }
}
