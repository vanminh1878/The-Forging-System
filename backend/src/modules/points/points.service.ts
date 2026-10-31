import { badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import { localDate, monthStartOf, startOfLocalDay } from '../../common/utils/time';
import { db } from '../../db/database';
import type { AuditService } from '../audit/audit.service';
import type { SettingsService } from '../settings/settings.service';
import type { PointsRepository } from './points.repository';
import type { MarksWallet, PointTransaction } from './points.repository';
import { applyMonthlyCap, MANUAL_ADJUST_CONFIRM_THRESHOLD } from './points.rules';

export interface AwardInput {
  memberId: string;
  source: string;
  dp?: number;
  marks?: number;
  note: string;
  /** Acting user; null = system. */
  by?: string | null;
  /** Prevents double posting when the triggering action is retried. */
  idempotencyKey?: string;
  attendanceId?: string;
  challengeParticipationId?: string;
  rankTrialRequestId?: string;
  redemptionId?: string;
  membershipId?: string;
  reason?: string;
}

export interface AwardResult {
  transaction: PointTransaction;
  /** True when the idempotency key had already been used; nothing new was written. */
  duplicate: boolean;
}

/** Port other modules depend on to touch the ledger (never write point_transactions directly). */
export interface PointsPort {
  award(input: AwardInput): Promise<AwardResult>;
}

/** Armory uses this while holding the tenant transaction used to create its pending redemption. */
export interface MarksWalletPort {
  wallet(memberId: string): Promise<MarksWallet>;
  assertMarksAvailable(memberId: string, amount: number): Promise<MarksWallet>;
}

export interface PointsAwardedEvent {
  memberId: string;
  dpDelta: number;
  marksDelta: number;
  source: string;
}

/**
 * The only writer of the point ledger. One ledger row carries both currencies
 * (dp_amount + marks_amount); DB triggers keep members.dp_balance /
 * marks_balance in sync and block updates/deletes of posted rows.
 */
export class PointsService implements PointsPort, MarksWalletPort {
  constructor(
    private readonly repo: PointsRepository,
    private readonly settings: SettingsService,
    private readonly audit: AuditService,
  ) {}

  async award(input: AwardInput): Promise<AwardResult> {
    const dp = input.dp ?? 0;
    const marks = input.marks ?? 0;
    const armoryDebit = input.source === 'ARMORY_REDEEM';
    const signedManualTransfer = input.source === 'MANUAL_ADJUSTMENT' && (dp < 0 || marks < 0);
    if (![dp, marks].every((amount) => Number.isInteger(amount) && Math.abs(amount) <= 2_147_483_647)) {
      throw badRequest('Point amounts must be valid integers.', undefined, 'INVALID_POINT_AMOUNT');
    }
    if (
      armoryDebit
        ? dp !== 0 || marks >= 0 || !input.redemptionId
        : !signedManualTransfer && (dp < 0 || marks < 0)
    ) {
      throw badRequest(
        'Negative awards are restricted to an Armory redemption debit.',
        undefined,
        'INVALID_AWARD',
      );
    }
    if (signedManualTransfer && (!input.by || !input.reason?.trim())) {
      throw badRequest('Signed manual transfers require an actor and reason.', undefined, 'INVALID_AWARD');
    }
    // A redemption has exactly one debit irrespective of a client retry key.
    const idempotencyKey = armoryDebit
      ? `${db.currentTenantId()}:armory:redeem:${input.redemptionId}`
      : input.idempotencyKey
        ? `${db.currentTenantId()}:${input.idempotencyKey}`
        : undefined;
    if (idempotencyKey) {
      const existing = await this.repo.findByIdempotencyKey(idempotencyKey);
      if (existing) return this.duplicateAward(existing, input);
    }

    // Serialise awards per member so the monthly-cap check is race free.
    const balances = await this.repo.lockMember(input.memberId);
    if (!balances) throw notFound('Member');

    // Recheck after waiting for the member lock; another retry may have posted while we waited.
    if (idempotencyKey) {
      const existing = await this.repo.findByIdempotencyKey(idempotencyKey);
      if (existing) return this.duplicateAward(existing, input);
    }

    let heldByOtherRedemptions = 0;
    if (signedManualTransfer) {
      if (balances.dpBalance + dp < 0 || balances.marksBalance + marks < 0) {
        throw unprocessable('The transfer would make a balance negative.', 'NEGATIVE_BALANCE');
      }
      if (marks < 0 && balances.marksBalance + marks < (await this.repo.heldMarks(input.memberId))) {
        throw unprocessable(
          'The transfer would consume Marks held for pending redemptions.',
          'INSUFFICIENT_AVAILABLE_MARKS',
        );
      }
    }

    if (armoryDebit) {
      // Serialize the order as well as the member. ARM-05 calls this before changing PENDING_PICKUP to DELIVERED.
      const existing = await this.repo.findRedemptionDebit(input.redemptionId!);
      if (existing) return this.duplicateAward(existing, input);
      const redemption = await this.repo.redemptionForDebit(input.redemptionId!);
      if (!redemption || redemption.memberId !== input.memberId) throw notFound('Redemption');
      if (!['PENDING_PICKUP', 'DELIVERED'].includes(redemption.status)) {
        throw conflict('Only a pending or delivered redemption can be debited.', 'REDEMPTION_NOT_PAYABLE');
      }
      if (redemption.marksCost !== -marks)
        throw badRequest(
          'Debit must equal the redemption Marks snapshot.',
          undefined,
          'REDEMPTION_AMOUNT_MISMATCH',
        );
      heldByOtherRedemptions = await this.repo.heldMarks(input.memberId, redemption.id);
      if (balances.marksBalance + marks < heldByOtherRedemptions) {
        throw unprocessable(
          'Marks balance cannot cover this debit and other pending holds.',
          'INSUFFICIENT_AVAILABLE_MARKS',
        );
      }
    }

    const now = clock.now();
    let capped: ReturnType<typeof applyMonthlyCap>;
    if (armoryDebit || signedManualTransfer) {
      capped = { dp, marks, capped: false };
    } else {
      const monthStart = startOfLocalDay(monthStartOf(localDate(now)));
      const [usage, dpCap, marksCap] = await Promise.all([
        this.repo.monthlyUsage(input.memberId, monthStart),
        this.settings.getNumber('points.dp_monthly_cap'),
        this.settings.getNumber('points.marks_monthly_cap'),
      ]);
      capped = applyMonthlyCap({
        source: input.source,
        dp,
        marks,
        usedDpThisMonth: usage.dp,
        usedMarksThisMonth: usage.marks,
        dpCap,
        marksCap,
      });
    }

    const tx = await this.repo.insert({
      memberId: input.memberId,
      source: input.source,
      dpAmount: capped.dp,
      marksAmount: capped.marks,
      isCapped: capped.capped,
      note: capped.capped ? `${input.note} · CAPPED theo hạn mức tháng` : input.note,
      idempotencyKey,
      attendanceId: input.attendanceId,
      challengeParticipationId: input.challengeParticipationId,
      rankTrialRequestId: input.rankTrialRequestId,
      redemptionId: input.redemptionId,
      membershipId: input.membershipId,
      reason: input.reason,
      createdBy: input.by ?? null,
      occurredAt: now,
    });
    if (!tx) {
      // Lost an idempotency race: another request inserted the same key first.
      const existing = await this.repo.findByIdempotencyKey(idempotencyKey!);
      return this.duplicateAward(existing!, input);
    }

    if (armoryDebit)
      await this.audit.record({
        actorId: input.by ?? null,
        action: 'ARMORY_MARKS_DEBITED',
        entityType: 'POINT_TRANSACTION',
        entityId: tx.id,
        before: { marksBalance: balances.marksBalance, heldByOtherRedemptions },
        after: { marksBalance: balances.marksBalance + marks, redemptionId: input.redemptionId },
        reason: input.reason ?? input.note,
      });

    if (tx.dpAmount !== 0 || tx.marksAmount !== 0) {
      const event: PointsAwardedEvent = {
        memberId: input.memberId,
        dpDelta: tx.dpAmount,
        marksDelta: tx.marksAmount,
        source: input.source,
      };
      await eventBus.emit(DomainEvents.POINTS_AWARDED, event);
    }
    return { transaction: tx, duplicate: false };
  }

  async wallet(memberId: string): Promise<MarksWallet> {
    const wallet = await this.repo.wallet(memberId);
    if (!wallet) throw notFound('Member');
    return wallet;
  }

  /** Called before the Armory module inserts its PENDING_PICKUP row; keep the transaction open. */
  async assertMarksAvailable(memberId: string, amount: number): Promise<MarksWallet> {
    if (!Number.isInteger(amount) || amount <= 0 || amount > 2_147_483_647)
      throw badRequest('Hold amount must be a positive integer.');
    if (!(await this.repo.lockMember(memberId))) throw notFound('Member');
    const wallet = await this.wallet(memberId);
    if (!wallet.canRedeem)
      throw forbidden('INACTIVE members cannot create new Armory redemptions.', 'MEMBER_INACTIVE');
    if (wallet.marksAvailable < amount)
      throw unprocessable('Marks available are insufficient.', 'INSUFFICIENT_AVAILABLE_MARKS');
    return wallet;
  }

  private duplicateAward(existing: PointTransaction, input: AwardInput): AwardResult {
    if (
      existing.memberId !== input.memberId ||
      existing.source !== input.source ||
      (input.source === 'ARMORY_REDEEM' &&
        (existing.redemptionId !== input.redemptionId || existing.marksAmount !== input.marks))
    ) {
      throw conflict('Idempotency key is already used by another point transaction.', 'IDEMPOTENCY_CONFLICT');
    }
    return { transaction: existing, duplicate: true };
  }

  /**
   * Admin manual correction (ADM-08). Positive or negative; always needs a
   * reason and is audited. Balances can never go below zero (DB check too).
   */
  async manualAdjust(input: {
    memberId: string;
    dpDelta: number;
    marksDelta?: number;
    reason: string;
    by: string;
    confirmed?: boolean;
  }): Promise<{ transaction: PointTransaction; dpBefore: number; dpAfter: number }> {
    const marksDelta = input.marksDelta ?? 0;
    if (!input.reason.trim()) throw badRequest('A reason is required for manual adjustments');
    if (input.dpDelta === 0 && marksDelta === 0) throw badRequest('Adjustment amount must not be zero');

    const balances = await this.repo.lockMember(input.memberId);
    if (!balances) throw notFound('Member');
    if (balances.dpBalance + input.dpDelta < 0 || balances.marksBalance + marksDelta < 0) {
      throw unprocessable('The adjustment would make a balance negative', 'NEGATIVE_BALANCE');
    }
    if (marksDelta < 0 && balances.marksBalance + marksDelta < (await this.repo.heldMarks(input.memberId))) {
      throw unprocessable(
        'The adjustment would consume Marks held for pending redemptions.',
        'INSUFFICIENT_AVAILABLE_MARKS',
      );
    }
    if (!input.confirmed && Math.abs(input.dpDelta) > MANUAL_ADJUST_CONFIRM_THRESHOLD) {
      throw unprocessable(
        `Adjustments above ${MANUAL_ADJUST_CONFIRM_THRESHOLD} DP need explicit confirmation`,
        'CONFIRMATION_REQUIRED',
      );
    }

    const tx = await this.repo.insert({
      memberId: input.memberId,
      source: 'MANUAL_ADJUSTMENT',
      dpAmount: input.dpDelta,
      marksAmount: marksDelta,
      isCapped: false,
      note: input.reason,
      reason: input.reason,
      createdBy: input.by,
    });
    await this.audit.record({
      actorId: input.by,
      action: 'DP_ADJUSTED',
      entityType: 'MEMBER',
      entityId: input.memberId,
      before: { dp: balances.dpBalance, marks: balances.marksBalance },
      after: { dp: balances.dpBalance + input.dpDelta, marks: balances.marksBalance + marksDelta },
      reason: input.reason,
    });
    await eventBus.emit(DomainEvents.POINTS_AWARDED, {
      memberId: input.memberId,
      dpDelta: input.dpDelta,
      marksDelta,
      source: 'MANUAL_ADJUSTMENT',
    } satisfies PointsAwardedEvent);
    return { transaction: tx!, dpBefore: balances.dpBalance, dpAfter: balances.dpBalance + input.dpDelta };
  }

  /** Reverses one posted transaction with an exact opposite row (never deletes). */
  async reverse(input: { transactionId: string; reason: string; by: string }): Promise<PointTransaction> {
    if (!input.reason.trim()) throw badRequest('A reason is required to reverse a transaction');
    const original = await this.repo.findById(input.transactionId);
    if (!original) throw notFound('Transaction');
    const balances = await this.repo.lockMember(original.memberId);
    if (!balances) throw notFound('Member');
    if (balances.dpBalance - original.dpAmount < 0 || balances.marksBalance - original.marksAmount < 0) {
      throw unprocessable('Reversing would make a balance negative', 'NEGATIVE_BALANCE');
    }
    if (
      original.marksAmount > 0 &&
      balances.marksBalance - original.marksAmount < (await this.repo.heldMarks(original.memberId))
    ) {
      throw unprocessable(
        'Reversal would consume Marks held for pending redemptions.',
        'INSUFFICIENT_AVAILABLE_MARKS',
      );
    }
    const tx = await this.repo.insert({
      memberId: original.memberId,
      source: 'REVERSAL',
      dpAmount: -original.dpAmount,
      marksAmount: -original.marksAmount,
      isCapped: false,
      note: `Đảo ngược giao dịch: ${input.reason}`,
      reason: input.reason,
      reversalOfId: original.id,
      createdBy: input.by,
    });
    await this.audit.record({
      actorId: input.by,
      action: 'DP_REVERSED',
      entityType: 'POINT_TRANSACTION',
      entityId: original.id,
      before: { dp: original.dpAmount, marks: original.marksAmount },
      reason: input.reason,
    });
    await eventBus.emit(DomainEvents.POINTS_AWARDED, {
      memberId: original.memberId,
      dpDelta: -original.dpAmount,
      marksDelta: -original.marksAmount,
      source: 'REVERSAL',
    } satisfies PointsAwardedEvent);
    return tx!;
  }

  async listForMember(memberId: string, filter: { source?: string }, limit: number, offset: number) {
    const [items, total] = await Promise.all([
      this.repo.list(memberId, filter, limit, offset),
      this.repo.count(memberId, filter),
    ]);
    return { items, total };
  }

  /** Usage of the monthly caps shown on the Fighter Record screen. */
  async monthlyStatus(memberId: string) {
    const monthStart = startOfLocalDay(monthStartOf(localDate(clock.now())));
    const [usage, dpCap, marksCap] = await Promise.all([
      this.repo.monthlyUsage(memberId, monthStart),
      this.settings.getNumber('points.dp_monthly_cap'),
      this.settings.getNumber('points.marks_monthly_cap'),
    ]);
    return { dpUsed: usage.dp, dpCap, marksUsed: usage.marks, marksCap };
  }

  reconcile(memberId: string) {
    return this.repo.reconcile(memberId);
  }
}
