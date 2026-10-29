import { randomUUID } from 'node:crypto';
import { badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { addMonthsToDate, localDate, monthStartOf, startOfLocalDay } from '../../common/utils/time';
import { db } from '../../db/database';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { PointsPort } from '../points/points.service';
import type { SettingsService } from '../settings/settings.service';
import type { RedeemableReward, RedemptionRepository } from './redemption.repository';
import type { CreateRedemptionInput } from './redemption.validation';

export class RedemptionService {
  constructor(private readonly repo: RedemptionRepository, private readonly audit: AuditService,
    private readonly points: PointsPort, private readonly notifier: NotifierPort, private readonly settings: SettingsService) {}

  async cancel(memberId: string, redemptionId: string, reason?: string) {
    if (!await this.repo.lockMember(memberId)) throw notFound('Member');
    const redemption = await this.repo.lockForMember(memberId, redemptionId);
    if (!redemption) throw notFound('Redemption');
    if (redemption.status === 'CANCELLED') return { redemption: await this.repo.getById(redemptionId), duplicate: true };
    if (redemption.status !== 'PENDING_PICKUP') throw conflict('Chỉ đơn đang chờ nhận mới có thể hủy.', 'REDEMPTION_NOT_CANCELLABLE');
    const why = reason?.trim() || 'Member cancelled before pickup';
    await this.transitionPending(redemption, 'CANCELLED', memberId, why);
    return { redemption: await this.repo.getById(redemptionId), duplicate: false };
  }

  async decide(input: { redemptionId: string; status: 'DELIVERED' | 'REJECTED'; reason?: string; deliveryEvidenceUrl?: string }, actor: { userId: string; branchId: string | null; roles: readonly string[] }) {
    // Match all redemption writers' lock order: member first, then redemption/reward.
    const memberId = await this.repo.memberIdForRedemption(input.redemptionId);
    if (!memberId) throw notFound('Redemption');
    if (!await this.repo.lockMember(memberId)) throw notFound('Member');
    const redemption = await this.repo.lockForStaff(input.redemptionId);
    if (!redemption) throw notFound('Redemption');
    const isAdmin = actor.roles.includes('ADMIN') || actor.roles.includes('SUPER_ADMIN');
    if (!isAdmin && actor.roles.includes('RECEPTIONIST') && actor.branchId !== redemption.pickupBranchId) {
      throw forbidden('Lễ tân chỉ xử lý đơn tại chi nhánh nhận đã chọn.', 'PICKUP_BRANCH_MISMATCH');
    }
    if (redemption.status === input.status) return { redemption: await this.repo.getById(input.redemptionId), duplicate: true };
    if (redemption.status !== 'PENDING_PICKUP') throw conflict('Đơn đổi quà đã được xử lý.', 'REDEMPTION_ALREADY_FINAL');
    if (input.status === 'DELIVERED') {
      await this.points.award({ memberId: redemption.memberId, source: 'ARMORY_REDEEM', dp: 0,
        marks: -redemption.marksCost, redemptionId: redemption.id, note: 'Armory redemption delivered',
        reason: input.reason ?? 'Gift handed over', by: actor.userId });
      const updated = await this.repo.setStatus({ id: redemption.id, status: 'DELIVERED', by: actor.userId,
        reason: input.reason?.trim() ?? null, evidenceUrl: input.deliveryEvidenceUrl });
      if (updated !== 1) throw conflict('Đơn đổi quà đã được xử lý đồng thời.', 'REDEMPTION_ALREADY_FINAL');
      await this.audit.record({ actorId: actor.userId, action: 'REDEMPTION_DELIVERED', entityType: 'REDEMPTION', entityId: redemption.id,
        before: { status: 'PENDING_PICKUP', marksHeld: redemption.marksCost },
        after: { status: 'DELIVERED', marksDebited: redemption.marksCost, evidenceUrl: input.deliveryEvidenceUrl ?? null },
        reason: input.reason?.trim() ?? 'Gift handed over' });
      await this.notify(redemption.memberId, NotificationEvent.ARMORY_DELIVERED,
        'QUÀ ARMORY ĐÃ ĐƯỢC GIAO', 'Đơn đổi quà của bạn đã được giao tại chi nhánh đã chọn.');
    } else {
      await this.transitionPending(redemption, 'REJECTED', actor.userId, input.reason!.trim());
    }
    return { redemption: await this.repo.getById(input.redemptionId), duplicate: false };
  }

  /** Batch hook: expire pending pickups after reward-specific or configured pickup days. */
  async expirePending(limit = 100): Promise<{ expired: number }> {
    const now = clock.now();
    const defaultDays = await this.settings.getNumber('armory.pending_pickup_expiry_days');
    const candidates = await this.repo.expiredCandidates(now, defaultDays, Math.max(1, Math.min(500, limit)));
    let expired = 0;
    for (const candidate of candidates) {
      if (!await this.repo.lockMember(candidate.memberId)) continue;
      const redemption = await this.repo.lockForStaff(candidate.redemptionId);
      if (!redemption || redemption.status !== 'PENDING_PICKUP') continue;
      const expiresAt = redemption.requestedAt.getTime() + (redemption.pickupDays ?? defaultDays) * 86_400_000;
      if (expiresAt > now.getTime()) continue;
      await this.transitionPending(redemption, 'EXPIRED', null, 'Pickup deadline expired');
      expired++;
    }
    return { expired };
  }

  private async transitionPending(redemption: NonNullable<Awaited<ReturnType<RedemptionRepository['lockForStaff']>>>,
    status: 'REJECTED' | 'CANCELLED' | 'EXPIRED', actorId: string | null, reason: string) {
    const updated = await this.repo.setStatus({ id: redemption.id, status, by: actorId, reason });
    if (updated !== 1) throw conflict('Đơn đổi quà đã được xử lý đồng thời.', 'REDEMPTION_ALREADY_FINAL');
    await this.repo.restoreStock(redemption, actorId, `Restock after ${status.toLowerCase()}: ${reason}`);
    await this.audit.record({ actorId, action: `REDEMPTION_${status}`, entityType: 'REDEMPTION', entityId: redemption.id,
      before: { status: 'PENDING_PICKUP', stockAllocated: true, marksHeld: redemption.marksCost },
      after: { status, stockRestored: true, marksHeld: 0 }, reason });
    if (status !== 'CANCELLED') await this.notify(redemption.memberId, NotificationEvent.ARMORY_REJECTED,
      status === 'EXPIRED' ? 'ĐƠN ĐỔI QUÀ ĐÃ HẾT HẠN' : 'ĐƠN ĐỔI QUÀ BỊ TỪ CHỐI',
      status === 'EXPIRED' ? 'Đơn quá hạn nhận. Hàng đã được hoàn về kho và Marks được giải phóng.' : `Đơn đổi quà bị từ chối: ${reason}. Hàng đã được hoàn về kho và Marks được giải phóng.`);
  }

  private notify(userId: string, event: string, title: string, body: string) {
    return this.notifier.notifyMember({ userId, event, title, body });
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
