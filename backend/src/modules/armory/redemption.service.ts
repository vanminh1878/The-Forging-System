import { randomUUID } from 'node:crypto';
import { badRequest, conflict, forbidden, notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { addMonthsToDate, localDate, monthStartOf, startOfLocalDay } from '../../common/utils/time';
import { db } from '../../db/database';
import type { AuditService } from '../audit/audit.service';
import { Role } from '../../shared/roles';
import type { AuthContext } from '../../common/http/request-context';
import type { MarksWalletPort, PointsPort } from '../points/points.service';
import type { RedeemableReward, RedemptionRepository, RedemptionState } from './redemption.repository';
import type { CreateRedemptionInput, RedemptionDecision } from './redemption.validation';

export class RedemptionService {
  constructor(private readonly repo: RedemptionRepository, private readonly audit: AuditService, private readonly points: MarksWalletPort & PointsPort) {}

  async cancel(memberId: string, id: string, reason?: string) {
    const order = await this.lockOrder(id, memberId);
    if (order.status === 'CANCELLED') return { redemption: order, duplicate: true };
    return this.close(order, 'CANCELLED', memberId, reason ?? null, null);
  }

  async decide(id: string, input: RedemptionDecision, actor: AuthContext) {
    const order = await this.lockOrder(id);
    const isAdmin = actor.roles.includes(Role.ADMIN) || actor.roles.includes(Role.SUPER_ADMIN);
    if (!isAdmin && actor.branchId !== order.pickupBranchId) {
      throw forbidden('Lễ tân chỉ xử lý đơn tại chi nhánh nhận.', 'PICKUP_BRANCH_MISMATCH');
    }
    if (order.status === input.status) return { redemption: order, duplicate: true };
    return this.close(order, input.status, actor.userId, input.reason ?? null,
      input.status === 'DELIVERED' ? input.deliveryEvidenceUrl ?? null : null);
  }

  /** Internal system hook; caller must check the expiry deadline before invoking it. */
  async expire(id: string, reason: string) {
    const order = await this.lockOrder(id);
    if (order.status === 'EXPIRED') return { redemption: order, duplicate: true };
    return this.close(order, 'EXPIRED', null, reason, null);
  }

  private async lockOrder(id: string, ownerId?: string): Promise<RedemptionState> {
    const memberId = await this.repo.memberForOrder(id);
    if (!memberId || (ownerId && ownerId !== memberId)) throw notFound('Redemption');
    // Consistent lock order with ARM-02 and ARM-04: member → order → reward.
    if (!await this.repo.lockMember(memberId)) throw notFound('Member');
    const order = await this.repo.lockOrder(id);
    if (!order || order.memberId !== memberId) throw notFound('Redemption');
    return order;
  }

  private async close(order: RedemptionState, status: 'DELIVERED' | 'REJECTED' | 'CANCELLED' | 'EXPIRED',
    actorId: string | null, reason: string | null, evidence: string | null) {
    if (order.status !== 'PENDING_PICKUP') throw conflict('Đơn đã kết thúc, không thể đổi trạng thái.', 'REDEMPTION_ALREADY_FINAL');
    if (status === 'DELIVERED') {
      await this.points.award({ memberId: order.memberId, source: 'ARMORY_REDEEM', marks: -order.marksCost,
        redemptionId: order.id, note: 'Giao quà Armory', by: actorId });
    }
    const updated = await this.repo.transition(order.id, status, actorId, reason, evidence);
    if (!updated) throw conflict('Đơn đã được xử lý.', 'REDEMPTION_ALREADY_FINAL');
    if (status !== 'DELIVERED') await this.repo.restoreStock(order, actorId, reason ?? status);
    await this.audit.record({ actorId, action: `REDEMPTION_${status}`, entityType: 'REDEMPTION', entityId: order.id,
      before: { status: order.status, marksCost: order.marksCost }, after: { status, marksCost: updated.marksCost }, reason });
    return { redemption: updated, duplicate: false };
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
      return { redemption: previous, wallet: await this.points.wallet(memberId), duplicate: true };
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
    // ARM-04 locks/checks the member wallet; the pending redemption below is the hold.
    const before = await this.points.assertMarksAvailable(memberId, reward.marksCost);
    const id = randomUUID();
    // Full UUID keeps the global redemption_code unique even across tenants.
    const redemption = await this.repo.create({ id, code: `ARM-${id.toUpperCase()}`, memberId,
      rewardId: reward.id, pickupBranchId: input.pickupBranchId, marksCost: reward.marksCost, key, at: now });
    if (await this.repo.consumeStock(reward.id) !== 1) throw conflict('Phần quà đã hết hàng.', 'OUT_OF_STOCK');
    await this.repo.inventoryOut(reward.id, redemption.id, memberId);
    const wallet = await this.points.wallet(memberId);
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
