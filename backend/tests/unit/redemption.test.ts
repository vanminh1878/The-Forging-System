import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../src/config/env', () => ({ env: { APP_TIMEZONE: 'Asia/Ho_Chi_Minh' } }));
vi.mock('../../src/db/database', () => ({ db: { currentTenantId: () => 'tenant' } }));
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { RedemptionService } from '../../src/modules/armory/redemption.service';
import { createRedemptionBody } from '../../src/modules/armory/redemption.validation';
import type { RedeemableReward, RedemptionRepository } from '../../src/modules/armory/redemption.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';

const input = { rewardId: randomUUID(), pickupBranchId: randomUUID(), idempotencyKey: randomUUID() };

describe('ARM-02 request validation', () => {
  it('normalizes UUID casing for consistent idempotency comparisons', () => {
    expect(createRedemptionBody.parse({ rewardId: input.rewardId.toUpperCase(), pickupBranchId: input.pickupBranchId.toUpperCase(), idempotencyKey: input.idempotencyKey.toUpperCase() })).toEqual(input);
  });
  it('accepts just the gift and pickup branch', () => {
    const simple = { rewardId: input.rewardId, pickupBranchId: input.pickupBranchId };
    expect(createRedemptionBody.parse(simple)).toEqual(simple);
  });
  it.each([
    { rewardId: 'bad' }, { pickupBranchId: 'bad' }, { idempotencyKey: 'bad' },
    { pickupBranchId: undefined }, { memberId: 'other' },
    { marksCost: 1 }, { quantity: 2 }, { status: 'DELIVERED' }, { requestedAt: '2026-10-01' },
  ])('rejects invalid or client-controlled field %j', (patch) => {
    expect(createRedemptionBody.safeParse({ ...input, ...patch }).success).toBe(false);
  });
});

describe('ARM-02 redemption rules', () => {
  const repo = { lockMember: vi.fn(), findByKey: vi.fn(), pickupBranchExists: vi.fn(), lockReward: vi.fn(),
    wallet: vi.fn(), memberRewardCount: vi.fn(), create: vi.fn(), consumeStock: vi.fn(), inventoryOut: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new RedemptionService(repo as unknown as RedemptionRepository, audit as unknown as AuditService);
  let reward: RedeemableReward;
  const previous = { id: 'order', rewardId: input.rewardId, pickupBranchId: input.pickupBranchId, status: 'PENDING_PICKUP', marksCost: 120 };

  beforeEach(() => {
    vi.resetAllMocks();
    setClock(fixedClock(new Date('2026-10-15T12:00:00Z')));
    reward = { id: input.rewardId, marksCost: 120, stock: 3, isActive: true, minRankId: null, minRankOrder: null,
      perMemberLimit: null, limitPeriod: null, saleStartsAt: null, saleEndsAt: null };
    repo.lockMember.mockResolvedValue({ id: 'member', status: 'ACTIVE', accountStatus: 'ACTIVE', rankOrder: 1 });
    repo.findByKey.mockResolvedValue(null);
    repo.pickupBranchExists.mockResolvedValue(true);
    repo.lockReward.mockImplementation(async () => reward);
    repo.wallet.mockResolvedValueOnce({ marksBalance: 300, marksHeld: 0, marksAvailable: 300 })
      .mockResolvedValue({ marksBalance: 300, marksHeld: 120, marksAvailable: 180 });
    repo.memberRewardCount.mockResolvedValue(0);
    repo.create.mockResolvedValue(previous);
    repo.consumeStock.mockResolvedValue(1);
  });
  afterEach(resetClock);

  it('creates a pending hold with a price snapshot, inventory OUT and audit', async () => {
    const result = await service.create('member', input);
    expect(result).toMatchObject({ duplicate: false, redemption: { marksCost: 120 }, wallet: { marksHeld: 120, marksAvailable: 180, marksBalance: 300 } });
    expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ marksCost: 120, memberId: 'member', pickupBranchId: input.pickupBranchId, key: `tenant:redeem:member:${input.idempotencyKey}` }));
    expect(repo.inventoryOut).toHaveBeenCalledWith(input.rewardId, 'order', 'member');
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'REDEMPTION_CREATED', actorId: 'member' }));
  });

  it('generates internal keys when the client supplies only two IDs', async () => {
    const simple = { rewardId: input.rewardId, pickupBranchId: input.pickupBranchId };
    await service.create('member', simple);
    await service.create('member', simple);
    const keys = repo.create.mock.calls.map(([order]) => order.key);
    expect(keys[0]).toMatch(/^tenant:redeem:member:[0-9a-f-]{36}$/);
    expect(keys[0]).not.toBe(keys[1]);
  });

  it('replays an existing key before rechecking mutable catalogue conditions', async () => {
    repo.findByKey.mockResolvedValue(previous);
    expect((await service.create('member', input)).duplicate).toBe(true);
    expect(repo.lockReward).not.toHaveBeenCalled();
    expect(repo.create).not.toHaveBeenCalled();
    expect(repo.consumeStock).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects key reuse with a different reward or branch', async () => {
    repo.findByKey.mockResolvedValue({ ...previous, pickupBranchId: 'other' });
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'IDEMPOTENCY_CONFLICT' });
  });

  it('rejects inactive/disabled accounts and invalid pickup branches', async () => {
    repo.lockMember.mockResolvedValueOnce({ status: 'INACTIVE', accountStatus: 'ACTIVE' });
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'MEMBER_INACTIVE' });
    repo.lockMember.mockResolvedValueOnce({ status: 'ACTIVE', accountStatus: 'LOCKED' });
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'ACCOUNT_DISABLED' });
    repo.pickupBranchExists.mockResolvedValue(false);
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'INVALID_PICKUP_BRANCH' });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it.each([
    { stock: 0, code: 'OUT_OF_STOCK' }, { isActive: false, code: 'REWARD_UNAVAILABLE' },
    { saleStartsAt: new Date('2026-10-16'), code: 'REWARD_UNAVAILABLE' },
    { saleEndsAt: new Date('2026-10-15T12:00:00Z'), code: 'REWARD_UNAVAILABLE' },
  ])('checks catalogue eligibility %j', async ({ code, ...patch }) => {
    Object.assign(reward, patch);
    await expect(service.create('member', input)).rejects.toMatchObject({ code });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('requires the configured rank and sufficient spendable, not total, Marks', async () => {
    reward.minRankId = 'rank'; reward.minRankOrder = 2;
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'RANK_REQUIRED' });
    reward.minRankId = null; reward.minRankOrder = null;
    repo.wallet.mockReset().mockResolvedValue({ marksBalance: 300, marksHeld: 250, marksAvailable: 50 });
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'INSUFFICIENT_AVAILABLE_MARKS' });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('enforces monthly quota using the server timezone boundary', async () => {
    setClock(fixedClock(new Date('2026-10-31T18:00:00Z')));
    reward.perMemberLimit = 1; reward.limitPeriod = 'MONTH';
    repo.memberRewardCount.mockResolvedValue(1);
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'REWARD_LIMIT_REACHED' });
    expect(repo.memberRewardCount).toHaveBeenCalledWith('member', input.rewardId, new Date('2026-10-31T17:00:00Z'), new Date('2026-11-30T17:00:00Z'));
  });

  it('uses lifetime quota without time boundaries', async () => {
    reward.perMemberLimit = 1; reward.limitPeriod = 'LIFETIME';
    await service.create('member', input);
    expect(repo.memberRewardCount).toHaveBeenCalledWith('member', input.rewardId, null, null);
  });

  it('rejects malformed legacy reward rules', async () => {
    reward.perMemberLimit = 1;
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'INVALID_REWARD_RULES' });
  });

  it('rejects missing members/rewards and failed stock consumption', async () => {
    repo.lockMember.mockResolvedValueOnce(null);
    await expect(service.create('member', input)).rejects.toMatchObject({ status: 404 });
    repo.lockReward.mockResolvedValueOnce(null);
    await expect(service.create('member', input)).rejects.toMatchObject({ status: 404 });
    repo.consumeStock.mockResolvedValueOnce(0);
    await expect(service.create('member', input)).rejects.toMatchObject({ code: 'OUT_OF_STOCK' });
  });
});
