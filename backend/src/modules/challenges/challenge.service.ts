import { badRequest, conflict, notFound } from '../../common/errors/app-error';
import type { AuditService } from '../audit/audit.service';
import type { ChallengeRepository, ChallengeView, ChallengeWrite } from './challenge.repository';
import type { ChallengeFilter, CreateChallengeInput, UpdateChallengeInput } from './challenge.validation';

const ruleFields = ['challengeType', 'context', 'target', 'rewardDp', 'rewardMarks', 'startsAt', 'endsAt'] as const;

export class ChallengeService {
  constructor(private readonly repo: ChallengeRepository, private readonly audit: AuditService) {}

  search(filter: ChallengeFilter, limit: number, offset: number) { return this.repo.search(filter, limit, offset); }

  async get(id: string): Promise<ChallengeView> {
    const challenge = await this.repo.find(id);
    if (!challenge) throw notFound('Challenge');
    return challenge;
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
