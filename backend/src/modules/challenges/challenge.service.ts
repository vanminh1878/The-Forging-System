import { badRequest, conflict, notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import type { AuditService } from '../audit/audit.service';
import type { ChallengeRepository, ChallengeView, ChallengeWrite, OpenChallengeView } from './challenge.repository';
import type { ChallengeEnabledInput, ChallengeFilter, CreateChallengeInput, OpenChallengeFilter, UpdateChallengeInput } from './challenge.validation';

const ruleFields = ['challengeType', 'context', 'target', 'rewardDp', 'rewardMarks', 'startsAt', 'endsAt'] as const;

export class ChallengeService {
  constructor(private readonly repo: ChallengeRepository, private readonly audit: AuditService) {}

  search(filter: ChallengeFilter, limit: number, offset: number) { return this.repo.search(filter, limit, offset); }

  async get(id: string): Promise<ChallengeView> {
    const challenge = await this.repo.find(id);
    if (!challenge) throw notFound('Challenge');
    return challenge;
  }

  async listOpenForMember(memberId: string, filter: OpenChallengeFilter, limit: number, offset: number): Promise<{ items: OpenChallengeView[]; total: number }> {
    const challengeType = filter.challengeType ?? filter.period ?? null;
    return this.repo.listOpenForMember(memberId, challengeType, filter.context ?? null, filter.q ?? null, clock.now(), limit, offset);
  }

  async create(input: CreateChallengeInput, actorId: string): Promise<ChallengeView> {
    const data = { ...input, startsAt: new Date(input.startsAt), endsAt: new Date(input.endsAt) };
    this.validateDates(data);
    await this.ensureUniqueCode(data.code);
    const after = await this.repo.create(data, actorId);
    await this.audit.record({ actorId, action: 'CHALLENGE_CREATED', entityType: 'CHALLENGE', entityId: after.id, after });
    return after;
  }

  async update(id: string, input: UpdateChallengeInput, actorId: string): Promise<ChallengeView> {
    const before = await this.repo.find(id, true);
    if (!before) throw notFound('Challenge');
    if (before.status === 'CANCELLED') throw conflict('Thử thách đã bị hủy, không thể chỉnh sửa.', 'CHALLENGE_CANCELLED');
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
    if (ruleFields.some((field) => !this.equal(before[field], after[field])) && await this.repo.hasParticipants(id)) {
      throw conflict('Không thể sửa điều kiện, phần thưởng hoặc thời gian khi đã có học viên tham gia.', 'CHALLENGE_RULES_LOCKED');
    }
    await this.ensureUniqueCode(after.code, id);
    if (Object.entries(after).every(([key, value]) => this.equal(before[key as keyof ChallengeWrite], value))) return before;
    const saved = await this.repo.update(id, after);
    await this.audit.record({ actorId, action: 'CHALLENGE_UPDATED', entityType: 'CHALLENGE', entityId: id, before, after: saved, reason });
    return saved;
  }

  /** Publishes/closes the catalogue entry without deciding any learner's participation. */
  async setEnabled(id: string, input: ChallengeEnabledInput, actorId: string): Promise<ChallengeView & { enabled: boolean }> {
    const before = await this.repo.find(id, true);
    if (!before) throw notFound('Challenge');
    if (input.enabled) {
      if (before.status === 'CANCELLED') throw conflict('Thử thách đã bị hủy, không thể mở lại.', 'CHALLENGE_CANCELLED');
      this.validateDates(before);
      if (before.endsAt.getTime() <= clock.now().getTime()) {
        throw conflict('Thử thách đã hết hạn, không thể bật.', 'CHALLENGE_EXPIRED');
      }
      if (!Number.isInteger(before.target) || before.target < 1 ||
        !Number.isInteger(before.rewardDp) || before.rewardDp < 0 ||
        !Number.isInteger(before.rewardMarks) || before.rewardMarks < 0) {
        throw badRequest('Mục tiêu và phần thưởng thử thách không hợp lệ.', undefined, 'INVALID_CHALLENGE_CONFIG');
      }
    }
    // Disabling a draft/cancelled/already-closed entry must not implicitly publish or revive it.
    if ((input.enabled && before.status === 'OPEN') || (!input.enabled && before.status !== 'OPEN')) {
      return { ...before, enabled: before.status === 'OPEN' };
    }
    const after = await this.repo.setStatus(id, input.enabled ? 'OPEN' : 'CLOSED');
    await this.audit.record({
      actorId, action: input.enabled ? 'CHALLENGE_ENABLED' : 'CHALLENGE_DISABLED',
      entityType: 'CHALLENGE', entityId: id, before, after, reason: input.reason,
    });
    return { ...after, enabled: after.status === 'OPEN' };
  }

  private validateDates(input: ChallengeWrite) {
    if (!Number.isFinite(input.startsAt.getTime()) || !Number.isFinite(input.endsAt.getTime()) || input.startsAt >= input.endsAt) {
      throw badRequest('Thời gian kết thúc phải sau thời gian bắt đầu.', undefined, 'INVALID_CHALLENGE_DATES');
    }
  }

  private async ensureUniqueCode(code: string | null, exceptId?: string) {
    if (code && await this.repo.codeExists(code, exceptId)) throw conflict('Mã thử thách đã được sử dụng.', 'CHALLENGE_CODE_TAKEN');
  }

  private equal(a: unknown, b: unknown): boolean { return a instanceof Date && b instanceof Date ? a.getTime() === b.getTime() : a === b; }
}
