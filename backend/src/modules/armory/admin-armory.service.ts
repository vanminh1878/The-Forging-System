import { badRequest, conflict, notFound } from '../../common/errors/app-error';
import type { AuditService } from '../audit/audit.service';
import type { AdminArmoryRepository, AdminRewardWrite } from './admin-armory.repository';
import type { AdminRewardFilter, CreateRewardInput, CreateTierInput, UpdateRewardInput, UpdateTierInput } from './admin-armory.validation';

export class AdminArmoryService {
  constructor(private readonly repo: AdminArmoryRepository, private readonly audit: AuditService) {}

  tiers() { return this.repo.tiers(); }
  search(filter: AdminRewardFilter, limit: number, offset: number) { return this.repo.search(filter, limit, offset); }
  async tier(code: string) { const tier = await this.repo.tier(code); if (!tier) throw notFound('Reward tier'); return tier; }
  async reward(id: string) { const reward = await this.repo.reward(id); if (!reward) throw notFound('Reward'); return reward; }

  async createTier(input: CreateTierInput, actorId: string) {
    this.validateTier(input);
    if (await this.repo.tierCodeExists(input.code)) throw conflict('Mã tầng đã tồn tại.', 'TIER_CODE_TAKEN');
    const after = await this.repo.createTier(input);
    await this.audit.record({ actorId, action: 'REWARD_TIER_CREATED', entityType: 'REWARD_TIER', entityId: after.code, after });
    return after;
  }
  async updateTier(code: string, input: UpdateTierInput, actorId: string) {
    const before = await this.repo.tier(code, true);
    if (!before) throw notFound('Reward tier');
    const { reason, ...patch } = input;
    const after = { ...before, ...patch };
    this.validateTier(after);
    if (this.unchanged(before, after)) return before;
    const saved = await this.repo.updateTier(after);
    await this.audit.record({ actorId, action: 'REWARD_TIER_UPDATED', entityType: 'REWARD_TIER', entityId: code, before, after: saved, reason });
    return saved;
  }
  async createReward(input: CreateRewardInput, actorId: string) {
    const data = { ...input, saleStartsAt: this.date(input.saleStartsAt), saleEndsAt: this.date(input.saleEndsAt) };
    await this.validateReward(data);
    if (await this.repo.skuExists(data.sku)) throw conflict('SKU phần quà đã tồn tại.', 'REWARD_SKU_TAKEN');
    const after = await this.repo.createReward(data);
    if (after.stock > 0) await this.repo.inventory(after.id, after.stock, actorId, 'Tồn kho ban đầu');
    await this.audit.record({ actorId, action: 'REWARD_CREATED', entityType: 'REWARD', entityId: after.id, after });
    return after;
  }
  async updateReward(id: string, input: UpdateRewardInput, actorId: string) {
    const before = await this.repo.reward(id, true);
    if (!before) throw notFound('Reward');
    const { reason, ...patch } = input;
    const after = { ...before, ...patch,
      saleStartsAt: patch.saleStartsAt === undefined ? before.saleStartsAt : this.date(patch.saleStartsAt),
      saleEndsAt: patch.saleEndsAt === undefined ? before.saleEndsAt : this.date(patch.saleEndsAt),
    };
    await this.validateReward(after);
    if (this.unchanged(before, after)) return before;
    const saved = await this.repo.updateReward(id, after);
    const delta = saved.stock - before.stock;
    if (delta !== 0) await this.repo.inventory(id, delta, actorId, reason);
    await this.audit.record({ actorId, action: 'REWARD_UPDATED', entityType: 'REWARD', entityId: id, before, after: saved, reason });
    return saved;
  }
  private validateTier(input: CreateTierInput) {
    if (input.maxMarks !== null && input.maxMarks < input.minMarks) throw badRequest('maxMarks phải >= minMarks.', undefined, 'INVALID_TIER_RANGE');
  }
  private async validateReward(input: AdminRewardWrite) {
    if ((input.perMemberLimit === null) !== (input.limitPeriod === null)) throw badRequest('Giới hạn đổi cần có cả số lượng và chu kỳ.', undefined, 'INVALID_REWARD_LIMIT');
    if (input.saleStartsAt && input.saleEndsAt && input.saleStartsAt >= input.saleEndsAt) throw badRequest('Thời gian kết thúc phải sau thời gian mở bán.', undefined, 'INVALID_REWARD_DATES');
    if (input.tierCode && !await this.repo.tier(input.tierCode)) throw badRequest('Tầng quà không tồn tại trong tenant.', undefined, 'INVALID_REWARD_TIER');
    if (input.minRankId && !await this.repo.rankExists(input.minRankId)) throw badRequest('Hạng không tồn tại trong tenant.', undefined, 'INVALID_REWARD_RANK');
  }
  private date(value: string | null): Date | null { return value === null ? null : new Date(value); }
  private unchanged(before: object, after: object): boolean {
    const values = before as Record<string, unknown>;
    return Object.entries(after).every(([key, value]) => value instanceof Date && values[key] instanceof Date
      ? value.getTime() === (values[key] as Date).getTime() : value === values[key]);
  }
}
