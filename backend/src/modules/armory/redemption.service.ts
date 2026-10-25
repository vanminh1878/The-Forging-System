import { randomUUID } from 'node:crypto';
import { badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { addMonthsToDate, localDate, monthStartOf, startOfLocalDay } from '../../common/utils/time';
import { db } from '../../db/database';
import type { AuditService } from '../audit/audit.service';
import type { RedeemableReward, RedemptionFilter, RedemptionRepository } from './redemption.repository';
import type { CreateRedemptionInput } from './redemption.validation';

export class RedemptionService {
  constructor(private readonly repo: RedemptionRepository, private readonly audit: AuditService) {}

  history(memberId: string, filter: RedemptionFilter, limit: number, offset: number) {
    return this.repo.listForMember(memberId, filter, limit, offset);
  }

  async detail(memberId: string, redemptionId: string) {
    const redemption = await this.repo.findForMember(memberId, redemptionId);
    if (!redemption) throw notFound('Redemption');
    return redemption;
  }

  async create(memberId: string, input: CreateRedemptionInput) {
    // All order writers lock the member first, then the pickup branch and reward.
    const member = await this.repo.lockMember(memberId);
    if (!member) throw notFound('Member');
    if (member.accountStatus !== 'ACTIVE') throw forbidden('Tài khoản đã bị khóa hoặc vô hiệu hóa.', 'ACCOUNT_DISABLED');
    const key = `${db.currentTenantId()}:redeem:${memberId}:${input.idempotencyKey ?? randomUUID()}`;
    const previous = await this.repo.findByKey(memberId, key);
    if (previous) {
      if (previous.rewardId !== input.rewardId || previous.pickupBranchId !== input.pickupBranchId) {
        throw conflict('Idempotency key đã được dùng cho yêu cầu đổi quà khác.', 'IDEMPOTENCY_CONFLICT');
      }
      return { redemption: previous, wallet: await this.repo.wallet(memberId), duplicate: true };
    }
    if (member.status === 'INACTIVE') throw forbidden('Tài khoản inactive không thể đổi quà.', 'MEMBER_INACTIVE');
    if (!await this.repo.pickupBranchExists(input.pickupBranchId)) throw badRequest('Chi nhánh nhận không hợp lệ hoặc đã ngừng hoạt động.', undefined, 'INVALID_PICKUP_BRANCH');
    const reward = await this.repo.lockReward(input.rewardId);
    if (!reward) throw notFound('Reward');
    const now = clock.now();
    this.validateReward(reward, now);
    if (!reward.isActive || (reward.saleStartsAt && now < reward.saleStartsAt) || (reward.saleEndsAt && now >= reward.saleEndsAt)) {
      throw conflict('Phần quà chưa mở, đã hết hạn hoặc đã tạm ngừng.', 'REWARD_UNAVAILABLE');
    }
    if (reward.stock < 1) throw conflict('Phần quà đã hết hàng.', 'OUT_OF_STOCK');
    if (reward.minRankOrder !== null && (member.rankOrder ?? 0) < reward.minRankOrder) {
      throw forbidden('Bạn chưa đạt hạng yêu cầu để đổi phần quà này.', 'RANK_REQUIRED');
    }
    if (reward.perMemberLimit !== null) {
      const period = this.period(reward.limitPeriod!, now);
      if (await this.repo.memberRewardCount(memberId, reward.id, period.start, period.end) >= reward.perMemberLimit) {
        throw conflict('Bạn đã đạt giới hạn đổi phần quà trong chu kỳ này.', 'REWARD_LIMIT_REACHED');
      }
    }
    const before = await this.repo.wallet(memberId);
    if (before.marksAvailable < reward.marksCost) throw unprocessable('HVP Marks khả dụng không đủ.', 'INSUFFICIENT_AVAILABLE_MARKS');
    const id = randomUUID();
    // Full UUID keeps the global redemption_code unique even across tenants.
    const redemption = await this.repo.create({ id, code: `ARM-${id.toUpperCase()}`, memberId,
      rewardId: reward.id, pickupBranchId: input.pickupBranchId, marksCost: reward.marksCost, key, at: now });
    if (await this.repo.consumeStock(reward.id) !== 1) throw conflict('Phần quà đã hết hàng.', 'OUT_OF_STOCK');
    await this.repo.inventoryOut(reward.id, redemption.id, memberId);
    const wallet = await this.repo.wallet(memberId);
    await this.audit.record({ actorId: memberId, action: 'REDEMPTION_CREATED', entityType: 'REDEMPTION', entityId: redemption.id,
      before: { ...before, stock: reward.stock }, after: { redemption, wallet, stock: reward.stock - 1 }, reason: 'Member requested Armory redemption' });
    return { redemption, wallet, duplicate: false };
  }

  private validateReward(reward: RedeemableReward, now: Date) {
    if (!Number.isInteger(reward.marksCost) || reward.marksCost < 1 ||
      (reward.minRankId !== null && reward.minRankOrder === null) ||
      ((reward.perMemberLimit === null) !== (reward.limitPeriod === null)) ||
      (reward.perMemberLimit !== null && (!Number.isInteger(reward.perMemberLimit) || reward.perMemberLimit < 1)) ||
      (reward.limitPeriod !== null && !['MONTH', 'YEAR', 'LIFETIME'].includes(reward.limitPeriod)) ||
      (reward.saleStartsAt && !Number.isFinite(reward.saleStartsAt.getTime())) ||
      (reward.saleEndsAt && !Number.isFinite(reward.saleEndsAt.getTime())) ||
      (reward.saleStartsAt && reward.saleEndsAt && reward.saleStartsAt >= reward.saleEndsAt) || !Number.isFinite(now.getTime())) {
      throw conflict('Cấu hình phần quà không hợp lệ.', 'INVALID_REWARD_RULES');
    }
  }

  private period(kind: 'MONTH' | 'YEAR' | 'LIFETIME', now: Date) {
    if (kind === 'LIFETIME') return { start: null, end: null };
    const date = localDate(now);
    const start = kind === 'MONTH' ? monthStartOf(date) : `${date.slice(0, 4)}-01-01`;
    return { start: startOfLocalDay(start), end: startOfLocalDay(addMonthsToDate(start, kind === 'MONTH' ? 1 : 12)) };
  }
}
