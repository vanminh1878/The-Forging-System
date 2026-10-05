import { conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { PointsPort } from '../points/points.service';
import type { SettingsService } from '../settings/settings.service';
import {
  canDecideTrial,
  coachCanOnlyRecommend,
  computeRankProgress,
  demotionTarget,
  rankByOrder,
  sortRanks,
} from './rank.engine';
import type { RankDef, RankProgress } from './rank.engine';
import type { RankRepository } from './rank.repository';
import type { MemberRankRow, RankTrialRow } from './rank.repository';

const NEAR_RANK_DP = 120;

export interface RankChangedEvent {
  memberId: string;
  fromOrder: number;
  toOrder: number;
  kind: 'UPGRADE' | 'RESTORE' | 'DEMOTE' | 'TRIAL_PASSED';
}

export interface RankProgressView extends RankProgress {
  missingCourses: { id: string; name: string }[];
  peakRankOrder: number;
}

const fmt = (n: number) => n.toLocaleString('vi-VN');

/** Port for modules that need to trigger a rank check after changing DP or courses. */
export interface RankPort {
  reevaluate(memberId: string): Promise<void>;
}

export class RankService implements RankPort {
  constructor(
    private readonly repo: RankRepository,
    private readonly points: PointsPort,
    private readonly notifier: NotifierPort,
    private readonly audit: AuditService,
    private readonly settings: SettingsService,
  ) {}

  // ---------- reading ----------

  listRanks(): Promise<RankDef[]> {
    return this.repo.listRanks().then(sortRanks);
  }

  /** Sets rank I + the INITIAL history row for a freshly created member. */
  async initializeMember(memberId: string): Promise<void> {
    const ranks = sortRanks(await this.repo.listRanks());
    const first = ranks[0];
    await this.repo.setRanks(memberId, first.id, first.id);
    await this.repo.insertHistory({
      memberId,
      fromRankId: null,
      toRankId: first.id,
      earnedVia: 'INITIAL',
      reason: 'Huy hiệu khởi đầu khi gia nhập HVP.',
      dpAtChange: 0,
    });
  }

  async progressFor(memberId: string): Promise<RankProgressView> {
    const ranks = sortRanks(await this.repo.listRanks());
    const state = await this.requireMember(memberId);
    const input = await this.buildInput(ranks, state);
    const progress = computeRankProgress(ranks, input, clock.now());
    const names = await this.repo.courseNames(progress.missingCourseIds);
    return {
      ...progress,
      missingCourses: progress.missingCourseIds.map((id) => ({ id, name: names.get(id) ?? id })),
      peakRankOrder: input.peakRankOrder,
    };
  }

  badges(memberId: string) {
    return this.repo.currentBadges(memberId);
  }

  history(memberId: string, limit = 50) {
    return this.repo.history(memberId, limit);
  }

  // ---------- automatic rank engine ----------

  /**
   * Re-checks a member after any DP / course change:
   *  1. demote while DP is below the current rank threshold (badge revoked);
   *  2. promote while every gate is satisfied (restoring a previously reached
   *     rank never needs a new Rank Trial).
   * Runs inside the caller's transaction.
   */
  async reevaluate(memberId: string): Promise<void> {
    const ranks = sortRanks(await this.repo.listRanks());
    const state = await this.repo.memberState(memberId, true);
    if (!state || !state.currentRankId) return;

    let current = ranks.find((r) => r.id === state.currentRankId)!;
    let peak = ranks.find((r) => r.id === (state.peakRankId ?? state.currentRankId))!;

    if (await this.settings.getBool('rank.demotion_enabled')) {
      const targetOrder = demotionTarget(ranks, current.rankOrder, state.dpBalance);
      while (current.rankOrder > targetOrder) {
        const lost = current;
        const lower = rankByOrder(ranks, lost.rankOrder - 1)!;
        await this.repo.insertHistory({
          memberId,
          fromRankId: lost.id,
          toRankId: lost.id,
          earnedVia: 'AUTO_DEMOTE',
          reason: `DP ${fmt(state.dpBalance)} thấp hơn ngưỡng ${fmt(lost.dpThreshold)} của ${lost.nameEn}.`,
          dpAtChange: state.dpBalance,
          isRevoked: true,
        });
        await this.repo.setRanks(memberId, lower.id, peak.id);
        await this.notifier.notifyMember({
          userId: memberId,
          event: NotificationEvent.RANK_LOST,
          title: 'RANK LOST',
          body: `Điểm DP xuống dưới ${fmt(lost.dpThreshold)} - bạn tụt về ${lower.nameEn}. Huy hiệu ${lost.nameEn} đã được gỡ. Quyền lợi & lớp nâng cao hạng ${lost.nameEn} vẫn được giữ; đủ điểm lại sẽ lấy lại hạng, không cần thi.`,
        });
        await this.notifier.notifyStaff('ADMIN', NotificationEvent.RANK_DOWN, 'TỤT HẠNG', `${state.fullName} tụt từ ${lost.nameEn} về ${lower.nameEn} (DP ${fmt(state.dpBalance)}).`);
        await this.audit.record({
          actorId: null,
          action: 'RANK_DEMOTED',
          entityType: 'MEMBER',
          entityId: memberId,
          before: { rank: lost.nameEn },
          after: { rank: lower.nameEn },
          reason: `DP ${state.dpBalance} < ngưỡng ${lost.dpThreshold}`,
        });
        await eventBus.emit(DomainEvents.RANK_CHANGED, {
          memberId,
          fromOrder: lost.rankOrder,
          toOrder: lower.rankOrder,
          kind: 'DEMOTE',
        } satisfies RankChangedEvent);
        current = lower;
      }
    }

    // Promotion loop (bounded by the number of ranks).
    for (let guard = 0; guard < ranks.length; guard++) {
      const input = await this.buildInput(ranks, { ...state, currentRankId: current.id, peakRankId: peak.id });
      const progress = computeRankProgress(ranks, input, clock.now());
      if (!progress.next || progress.status !== 'RANK_READY') {
        await this.maybeNotifyNearRank(memberId, progress, state.dpBalance);
        break;
      }
      const restored = progress.next.rankOrder <= peak.rankOrder;
      const next = progress.next;
      const reasonParts = [`Đạt ${fmt(next.dpThreshold)} DP`];
      if (next.minActiveMonths) reasonParts.push(`đủ ${next.minActiveMonths} tháng luyện tập`);
      if (next.requiredCourseIds.length) {
        const names = await this.repo.courseNames(next.requiredCourseIds);
        reasonParts.push(`hoàn thành khóa ${next.requiredCourseIds.map((id) => names.get(id) ?? id).join(' + ')}`);
      }
      await this.grantRank(state, current, next, peak, {
        via: restored ? 'RESTORED' : 'AUTO_UPGRADE',
        reason: restored
          ? `Khôi phục huy hiệu: đủ DP trở lại, không cần thi lại. (${reasonParts.join(', ')})`
          : `${reasonParts.join(', ')}.`,
        by: null,
      });
      current = next;
      if (next.rankOrder > peak.rankOrder) peak = next;
    }
  }

  // ---------- rank trial ----------

  async requestTrial(memberId: string) {
    const progress = await this.progressFor(memberId);
    if (progress.status !== 'TRIAL_REQUIRED' || !progress.next) {
      throw unprocessable(
        'Bạn chưa đủ điều kiện để yêu cầu Rank Trial. Vui lòng xem điều kiện còn thiếu tại Fighter Record.',
        'TRIAL_NOT_AVAILABLE',
      );
    }
    const next = progress.next;
    const approver = next.approvalRole ?? 'COACH';
    const state = await this.requireMember(memberId);
    let trial: RankTrialRow | null;
    try {
      trial = await this.repo.insertTrial({
        memberId,
        targetRankId: next.id,
        approverRole: approver,
        snapshot: { dp: state.dpBalance, monthsIn: Math.round(progress.monthsIn * 10) / 10, rank: progress.current.nameEn },
      });
    } catch (err) {
      if ((err as { code?: string }).code === '23505') throw conflict('Bạn đã có một yêu cầu Rank Trial đang chờ xử lý.', 'TRIAL_ALREADY_OPEN');
      throw err;
    }
    const approverLabel = approver === 'ADMIN' ? 'Quản trị viên' : approver === 'HEAD_COACH' ? 'Head Coach' : 'Coach phụ trách';
    await this.notifier.notifyMember({
      userId: memberId,
      event: NotificationEvent.RANK_TRIAL_REQUESTED,
      title: 'YÊU CẦU ĐÃ GỬI',
      body: `Yêu cầu Rank Trial lên ${next.nameEn} đã được gửi tới ${approverLabel}.`,
    });
    await this.notifier.notifyStaff(
      approver === 'ADMIN' ? 'ADMIN' : 'COACH',
      approver === 'ADMIN' ? NotificationEvent.RANK_TRIAL_ADMIN : NotificationEvent.RANK_TRIAL_REQUEST,
      'Rank Trial chờ xử lý',
      `${state.fullName} yêu cầu Rank Trial lên ${next.nameEn}.`,
    );
    return trial!;
  }

  /**
   * Examiner decision. For ranks that only an Admin can finalise, a coach's PASS
   * is stored as a recommendation and the request stays PENDING.
   */
  async decideTrial(input: {
    trialId: string;
    result: 'PASS' | 'FAIL';
    note?: string;
    by: string;
    byName: string;
    roles: readonly string[];
  }): Promise<{ status: string; recommendationOnly: boolean }> {
    const trial = await this.repo.getTrial(input.trialId, true);
    if (!trial) throw notFound('Rank trial');
    if (trial.status !== 'PENDING' && trial.status !== 'SCHEDULED') throw conflict('Yêu cầu này đã được xử lý.', 'TRIAL_ALREADY_DECIDED');
    if (!canDecideTrial(trial.approverRole, input.roles)) throw forbidden('Bạn không có quyền chấm Rank Trial của hạng này.');

    const ranks = sortRanks(await this.repo.listRanks());
    const target = ranks.find((r) => r.id === trial.targetRankId)!;
    const state = await this.requireMember(trial.memberId);

    if (input.result === 'PASS' && coachCanOnlyRecommend(trial.approverRole, input.roles)) {
      await this.repo.updateTrial({
        id: trial.id,
        status: 'PENDING',
        evaluatedBy: null,
        note: null,
        snapshot: {
          ...trial.eligibilitySnapshot,
          coachRecommendation: { by: input.byName, byId: input.by, result: 'PASS', note: input.note ?? null, at: clock.now().toISOString() },
        },
      });
      await this.notifier.notifyStaff('ADMIN', NotificationEvent.RANK_TRIAL_ADMIN, 'Hạng danh dự chờ phê duyệt', `${state.fullName} được ${input.byName} đề xuất lên ${target.nameEn}.`);
      return { status: 'PENDING', recommendationOnly: true };
    }

    if (input.result === 'FAIL') {
      await this.repo.updateTrial({ id: trial.id, status: 'FAILED', evaluatedBy: input.by, note: input.note ?? null });
      await this.notifier.notifyMember({
        userId: trial.memberId,
        event: NotificationEvent.RANK_TRIAL_FAILED,
        title: 'RANK TRIAL CHƯA ĐẠT',
        body: `Yêu cầu Rank Trial lên ${target.nameEn} chưa đạt. Hạng hiện tại được giữ nguyên - bạn có thể yêu cầu lại khi đủ điều kiện.`,
      });
      await this.audit.record({
        actorId: input.by,
        action: 'RANK_REJECTED',
        entityType: 'MEMBER',
        entityId: trial.memberId,
        after: { targetRank: target.nameEn },
        reason: input.note ?? `Rank Trial ${target.nameEn} - Không đạt`,
      });
      return { status: 'FAILED', recommendationOnly: false };
    }

    // PASS: gates other than the trial must still hold at decision time.
    const progress = await this.progressFor(trial.memberId);
    if (!progress.next || progress.next.id !== target.id || !progress.dpOk || !progress.timeOk || !progress.courseOk) {
      throw unprocessable('Học viên không còn đáp ứng điều kiện DP / thời gian / khóa học cho hạng này.', 'GATES_NOT_MET');
    }
    await this.repo.updateTrial({ id: trial.id, status: 'PASSED', evaluatedBy: input.by, note: input.note ?? null });
    const current = ranks.find((r) => r.rankOrder === progress.current.rankOrder)!;
    const courseNames = await this.repo.courseNames(target.requiredCourseIds);
    const peakRank = ranks.find((r) => r.rankOrder === progress.peakRankOrder)!;
    await this.grantRank(state, current, target, peakRank, {
      via: 'RANK_TRIAL_PASSED',
      reason: `Vượt qua Rank Trial do ${input.byName} chấm${input.note ? ` - "${input.note}"` : ''}. Đủ ${fmt(target.dpThreshold)} DP, ${target.minActiveMonths} tháng${target.requiredCourseIds.length ? `, khóa ${target.requiredCourseIds.map((id) => courseNames.get(id) ?? id).join(' + ')}` : ''}.`,
      by: input.by,
      trialId: trial.id,
    });
    await this.points.award({
      memberId: trial.memberId,
      source: 'RANK_TRIAL',
      dp: await this.settings.getNumber('points.rank_trial_bonus_dp'),
      marks: await this.settings.getNumber('points.rank_trial_bonus_marks'),
      note: `Thưởng Rank Trial đạt ${target.nameEn}`,
      by: input.by,
      rankTrialRequestId: trial.id,
      idempotencyKey: `rank-trial:${trial.id}`,
    });
    await this.audit.record({
      actorId: input.by,
      action: 'RANK_APPROVED',
      entityType: 'MEMBER',
      entityId: trial.memberId,
      before: { rank: current.nameEn },
      after: { rank: target.nameEn },
      reason: input.note ?? `Rank Trial ${target.nameEn} - Đạt`,
    });
    return { status: 'PASSED', recommendationOnly: false };
  }

  listTrials(filter: { status?: string[]; approverRoles?: string[]; memberId?: string }, limit = 50) {
    return this.repo.listTrials(filter, limit);
  }

  /** Approver roles whose requests a user may see in their queue. */
  approverRolesVisibleTo(roles: readonly string[]): string[] {
    if (roles.includes('ADMIN') || roles.includes('SUPER_ADMIN')) return ['COACH', 'HEAD_COACH', 'ADMIN'];
    const out = ['COACH'];
    if (roles.includes('HEAD_COACH')) out.push('HEAD_COACH');
    return out;
  }

  // ---------- internals ----------

  private async requireMember(memberId: string): Promise<MemberRankRow> {
    const state = await this.repo.memberState(memberId);
    if (!state || !state.currentRankId) throw notFound('Member');
    return state;
  }

  private async buildInput(ranks: RankDef[], state: Pick<MemberRankRow, 'userId' | 'joinedAt' | 'dpBalance' | 'currentRankId' | 'peakRankId'>) {
    const current = ranks.find((r) => r.id === state.currentRankId)!;
    const peak = ranks.find((r) => r.id === (state.peakRankId ?? state.currentRankId))!;
    const next = rankByOrder(ranks, current.rankOrder + 1);
    return {
      currentRankOrder: current.rankOrder,
      peakRankOrder: Math.max(peak.rankOrder, current.rankOrder),
      dpBalance: state.dpBalance,
      joinedAt: state.joinedAt,
      completedCourseIds: await this.repo.completedCourseIds(state.userId),
      latestTrialStatus: next ? await this.repo.latestTrialStatus(state.userId, next.id) : null,
    };
  }

  private async grantRank(
    state: MemberRankRow,
    from: RankDef,
    to: RankDef,
    peak: RankDef,
    opts: { via: 'AUTO_UPGRADE' | 'RESTORED' | 'RANK_TRIAL_PASSED'; reason: string; by: string | null; trialId?: string },
  ): Promise<void> {
    const newPeak = peak.rankOrder >= to.rankOrder ? peak.id : to.id;
    await this.repo.insertHistory({
      memberId: state.userId,
      fromRankId: from.id,
      toRankId: to.id,
      earnedVia: opts.via,
      reason: opts.reason,
      dpAtChange: state.dpBalance,
      trialId: opts.trialId,
      approvedBy: opts.by,
    });
    await this.repo.setRanks(state.userId, to.id, newPeak);
    // Keep the in-memory snapshot coherent for the next loop iteration.
    state.currentRankId = to.id;
    state.peakRankId = newPeak;
    await this.notifier.notifyFromTemplate(state.userId, NotificationEvent.RANK_EARNED, { rank: to.nameEn });
    const restoredLabel = opts.via === 'RESTORED' ? ' (khôi phục, không thi lại)' : '';
    await this.notifier.notifyStaff('ADMIN', NotificationEvent.RANK_UP, 'LÊN HẠNG', `${state.fullName} đã đạt ${to.nameEn}${restoredLabel}.`);
    await this.audit.record({
      actorId: opts.by,
      action: opts.via === 'RESTORED' ? 'RANK_RESTORED' : 'RANK_UPGRADED',
      entityType: 'MEMBER',
      entityId: state.userId,
      before: { rank: from.nameEn },
      after: { rank: to.nameEn },
      reason: opts.reason,
    });
    await eventBus.emit(DomainEvents.RANK_CHANGED, {
      memberId: state.userId,
      fromOrder: from.rankOrder,
      toOrder: to.rankOrder,
      kind: opts.via === 'RESTORED' ? 'RESTORE' : opts.via === 'RANK_TRIAL_PASSED' ? 'TRIAL_PASSED' : 'UPGRADE',
    } satisfies RankChangedEvent);
  }

  private async maybeNotifyNearRank(memberId: string, progress: RankProgress, dp: number): Promise<void> {
    if (!progress.next || !progress.dpRemaining || progress.dpRemaining > NEAR_RANK_DP || dp <= 0) return;
    await this.notifier.notifyFromTemplate(
      memberId,
      NotificationEvent.NEAR_RANK,
      { remain: progress.dpRemaining, nextRank: progress.next.nameEn },
      { dedupeKey: `near-rank:${memberId}:${progress.next.id}` },
    );
  }
}

