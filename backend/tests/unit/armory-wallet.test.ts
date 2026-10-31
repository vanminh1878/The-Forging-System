import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../src/config/env', () => ({ env: { NODE_ENV: 'test', LOG_LEVEL: 'silent', APP_TIMEZONE: 'Asia/Ho_Chi_Minh' }, isProd: true }));
vi.mock('../../src/db/database', () => ({ db: { currentTenantId: () => 'tenant' } }));
vi.mock('../../src/common/events/event-bus', () => ({ DomainEvents: { POINTS_AWARDED: 'points.awarded' }, eventBus: { emit: vi.fn() } }));
import { PointsService } from '../../src/modules/points/points.service';
import type { PointsRepository, PointTransaction } from '../../src/modules/points/points.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { SettingsService } from '../../src/modules/settings/settings.service';

describe('ARM-04 debit and hold rules', () => {
  const repo = { findByIdempotencyKey: vi.fn(), lockMember: vi.fn(), findRedemptionDebit: vi.fn(), redemptionForDebit: vi.fn(), heldMarks: vi.fn(), wallet: vi.fn(), monthlyUsage: vi.fn(), insert: vi.fn() };
  const settings = { getNumber: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new PointsService(repo as unknown as PointsRepository, settings as unknown as SettingsService, audit as unknown as AuditService);
  const debit = { memberId: 'member', source: 'ARMORY_REDEEM', dp: 0, marks: -80, redemptionId: 'order', note: 'Gift delivered' };
  const transaction = { id: 'transaction', memberId: 'member', source: 'ARMORY_REDEEM', dpAmount: 0, marksAmount: -80, redemptionId: 'order' } as PointTransaction;

  beforeEach(() => {
    vi.resetAllMocks();
    repo.findByIdempotencyKey.mockResolvedValue(null);
    repo.findRedemptionDebit.mockResolvedValue(null);
    repo.lockMember.mockResolvedValue({ dpBalance: 0, marksBalance: 200, status: 'ACTIVE' });
    repo.redemptionForDebit.mockResolvedValue({ id: 'order', memberId: 'member', marksCost: 80, status: 'PENDING_PICKUP' });
    repo.heldMarks.mockResolvedValue(40);
    repo.wallet.mockResolvedValue({ memberId: 'member', status: 'ACTIVE', marksBalance: 200, marksHeld: 40, marksAvailable: 160, canRedeem: true });
    repo.insert.mockResolvedValue(transaction);
    repo.monthlyUsage.mockResolvedValue({ dp: 0, marks: 149 });
    settings.getNumber.mockImplementation(async (key) => key === 'points.dp_monthly_cap' ? 1200 : 150);
  });

  it('debits the exact snapshot without touching monthly-cap usage', async () => {
    const result = await service.award(debit);
    expect(result.duplicate).toBe(false);
    expect(repo.insert).toHaveBeenCalledWith(expect.objectContaining({ dpAmount: 0, marksAmount: -80, isCapped: false, idempotencyKey: 'tenant:armory:redeem:order' }));
    expect(repo.heldMarks).toHaveBeenCalledWith('member', 'order');
    expect(repo.monthlyUsage).not.toHaveBeenCalled();
    expect(settings.getNumber).not.toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'ARMORY_MARKS_DEBITED' }));
  });

  it('keeps normal positive awards capped', async () => {
    await service.award({ memberId: 'member', source: 'SESSION', marks: 10, note: 'Session' });
    expect(repo.insert).toHaveBeenCalledWith(expect.objectContaining({ marksAmount: 1, isCapped: true }));
  });

  it('preserves signed manual transfers used by account merge, with actor and reason', async () => {
    await service.award({ memberId: 'member', source: 'MANUAL_ADJUSTMENT', marks: -100, note: 'Merge transfer', reason: 'Merge transfer', by: 'admin' });
    expect(repo.insert).toHaveBeenCalledWith(expect.objectContaining({ marksAmount: -100, isCapped: false }));
    await expect(service.award({ memberId: 'member', source: 'MANUAL_ADJUSTMENT', marks: -100, note: 'No actor' })).rejects.toMatchObject({ status: 400 });
  });

  it.each([
    { source: 'SESSION', marks: -1 }, { dp: -1 }, { dp: 1 }, { marks: 0 },
    { marks: 80 }, { redemptionId: undefined }, { marks: -1.5 }, { marks: -Infinity },
  ])('rejects invalid debits %j', async (patch) => {
    await expect(service.award({ ...debit, ...patch })).rejects.toMatchObject({ status: 400 });
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('refuses a debit that would consume another order hold', async () => {
    repo.lockMember.mockResolvedValue({ dpBalance: 0, marksBalance: 100, status: 'ACTIVE' });
    await expect(service.award(debit)).rejects.toMatchObject({ code: 'INSUFFICIENT_AVAILABLE_MARKS' });
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('validates order ownership, status, and snapshot amount', async () => {
    repo.redemptionForDebit.mockResolvedValueOnce({ memberId: 'other' });
    await expect(service.award(debit)).rejects.toMatchObject({ status: 404 });
    repo.redemptionForDebit.mockResolvedValueOnce({ memberId: 'member', status: 'REJECTED' });
    await expect(service.award(debit)).rejects.toMatchObject({ code: 'REDEMPTION_NOT_PAYABLE' });
    repo.redemptionForDebit.mockResolvedValueOnce({ memberId: 'member', status: 'PENDING_PICKUP', marksCost: 100 });
    await expect(service.award(debit)).rejects.toMatchObject({ code: 'REDEMPTION_AMOUNT_MISMATCH' });
  });

  it('rechecks duplicate keys after waiting for the member lock', async () => {
    repo.findByIdempotencyKey.mockResolvedValueOnce(null).mockResolvedValueOnce(transaction);
    repo.lockMember.mockResolvedValue({ marksBalance: 0 });
    expect((await service.award(debit)).duplicate).toBe(true);
    expect(repo.redemptionForDebit).not.toHaveBeenCalled();
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('deduplicates by order even if a different key was supplied', async () => {
    repo.findRedemptionDebit.mockResolvedValue(transaction);
    expect((await service.award({ ...debit, idempotencyKey: 'different-key' })).duplicate).toBe(true);
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('does not reuse an idempotency key from another member', async () => {
    repo.findByIdempotencyKey.mockResolvedValue({ ...transaction, memberId: 'other' });
    await expect(service.award(debit)).rejects.toMatchObject({ code: 'IDEMPOTENCY_CONFLICT' });
  });

  it('checks spendable Marks under lock without posting a hold transaction', async () => {
    expect(await service.assertMarksAvailable('member', 160)).toMatchObject({ marksAvailable: 160, marksHeld: 40 });
    expect(repo.lockMember).toHaveBeenCalledWith('member');
    expect(repo.insert).not.toHaveBeenCalled();
    await expect(service.assertMarksAvailable('member', 161)).rejects.toMatchObject({ code: 'INSUFFICIENT_AVAILABLE_MARKS' });
  });

  it('rejects new holds for inactive members and invalid amounts', async () => {
    repo.wallet.mockResolvedValue({ canRedeem: false, marksAvailable: 1000 });
    await expect(service.assertMarksAvailable('member', 1)).rejects.toMatchObject({ code: 'MEMBER_INACTIVE' });
    await expect(service.assertMarksAvailable('member', 0)).rejects.toMatchObject({ status: 400 });
  });
});
