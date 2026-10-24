import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminArmoryService } from '../../src/modules/armory/admin-armory.service';
import type { AdminArmoryRepository, AdminReward } from '../../src/modules/armory/admin-armory.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';
import { adminRewardQuery, createRewardBody, createTierBody, updateRewardBody, updateTierBody } from '../../src/modules/armory/admin-armory.validation';

describe('GFT-01 request validation', () => {
  it('normalizes stable identifiers and sets optional defaults', () => {
    expect(createTierBody.parse({ code: ' test_tier ', name: ' Tier ', minMarks: 0 })).toMatchObject({ code: 'TEST_TIER', name: 'Tier', maxMarks: null, sortOrder: 0 });
    expect(createRewardBody.parse({ sku: ' wraps-01 ', name: ' Wraps ', marksCost: 100 })).toMatchObject({ sku: 'WRAPS-01', name: 'Wraps', stock: 0, tierCode: null, isActive: true, perMemberLimit: null, limitPeriod: null });
    expect(adminRewardQuery.parse({ isActive: 'false' }).isActive).toBe(false);
    expect(adminRewardQuery.parse({}).isActive).toBeUndefined();
  });

  it.each([
    { marksCost: 0 }, { marksCost: -1 }, { marksCost: 1.5 }, { marksCost: '100' },
    { stock: -1 }, { stock: 1.5 }, { stock: 2_147_483_648 },
    { perMemberLimit: 0 }, { pickupDays: 32768 }, { pickupDays: 0 },
    { imageUrl: 'ftp://test.local/image' }, { imageUrl: 'javascript:alert(1)' },
    { minRankId: 'bad' }, { saleStartsAt: '2026-10-01' }, { isActive: 'false' }, { tenantId: 'other' },
  ])('rejects invalid reward fields %j', (patch) => {
    expect(createRewardBody.safeParse({ sku: 'SKU-01', name: 'Reward', marksCost: 100, ...patch }).success).toBe(false);
  });

  it('requires meaningful update fields and reasons and keeps codes/SKUs immutable', () => {
    expect(updateTierBody.safeParse({ reason: 'No changes' }).success).toBe(false);
    expect(updateRewardBody.safeParse({ stock: 5 }).success).toBe(false);
    expect(updateRewardBody.safeParse({ sku: 'NEW_SKU', reason: 'Rename' }).success).toBe(false);
    expect(updateTierBody.safeParse({ code: 'NEW_CODE', reason: 'Rename' }).success).toBe(false);
    expect(updateRewardBody.safeParse({ tierCode: null, reason: 'Clear tier' }).success).toBe(true);
    expect(createTierBody.safeParse({ code: 'TEST', name: 'Tier', minMarks: 0, sortOrder: 32768 }).success).toBe(false);
  });
});

describe('GFT-01 business rules', () => {
  const repo = { tier: vi.fn(), tierCodeExists: vi.fn(), createTier: vi.fn(), updateTier: vi.fn(), skuExists: vi.fn(),
    rankExists: vi.fn(), reward: vi.fn(), createReward: vi.fn(), updateReward: vi.fn(), inventory: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new AdminArmoryService(repo as unknown as AdminArmoryRepository, audit as unknown as AuditService);
  let reward: AdminReward;
  beforeEach(() => {
    vi.resetAllMocks();
    reward = { ...createRewardBody.parse({ sku: 'WRAPS', name: 'Wraps', marksCost: 100, stock: 10 }), id: 'reward', saleStartsAt: null, saleEndsAt: null, createdAt: new Date('2026-10-01'), updatedAt: new Date('2026-10-01') };
    repo.reward.mockResolvedValue(reward);
    repo.tier.mockResolvedValue(createTierBody.parse({ code: 'TEST', name: 'Test tier', minMarks: 50, maxMarks: 100 }));
    repo.rankExists.mockResolvedValue(true);
    repo.skuExists.mockResolvedValue(false);
    repo.tierCodeExists.mockResolvedValue(false);
    repo.createTier.mockImplementation(async (input) => input);
    repo.updateTier.mockImplementation(async (input) => input);
    repo.createReward.mockImplementation(async (input) => ({ ...reward, ...input }));
    repo.updateReward.mockImplementation(async (_id, input) => ({ ...reward, ...input }));
  });

  it('records an initial stock movement only for positive stock', async () => {
    await service.createReward(createRewardBody.parse({ sku: 'FIRST', name: 'Gift', marksCost: 80, stock: 5 }), 'admin');
    expect(repo.inventory).toHaveBeenCalledWith(reward.id, 5, 'admin', expect.any(String));
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'REWARD_CREATED', actorId: 'admin' }));
    repo.inventory.mockClear();
    await service.createReward(createRewardBody.parse({ sku: 'SECOND', name: 'Gift', marksCost: 80 }), 'admin');
    expect(repo.inventory).not.toHaveBeenCalled();
  });

  it('records stock delta after locking the reward and preserves other metadata', async () => {
    const result = await service.updateReward(reward.id, { stock: 4, reason: 'Stock correction' }, 'admin');
    expect(repo.reward).toHaveBeenCalledWith(reward.id, true);
    expect(repo.inventory).toHaveBeenCalledWith(reward.id, -6, 'admin', 'Stock correction');
    expect(result.marksCost).toBe(100);
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'REWARD_UPDATED', before: reward, after: expect.objectContaining({ stock: 4 }) }));
  });

  it('checks merged tier ranges on partial patch', async () => {
    await expect(service.updateTier('TEST', { minMarks: 120, reason: 'Invalid range' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_TIER_RANGE' });
    expect(repo.updateTier).not.toHaveBeenCalled();
    expect((await service.updateTier('TEST', { maxMarks: null, reason: 'Open-ended tier' }, 'admin')).maxMarks).toBeNull();
  });

  it('validates date intervals and per-member limit pairs after merge', async () => {
    reward.saleStartsAt = new Date('2026-10-01T00:00:00Z');
    reward.saleEndsAt = new Date('2026-11-01T00:00:00Z');
    await expect(service.updateReward(reward.id, { saleStartsAt: '2026-12-01T00:00:00Z', reason: 'Invalid dates' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_REWARD_DATES' });
    await expect(service.updateReward(reward.id, { perMemberLimit: 1, reason: 'Missing period' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_REWARD_LIMIT' });
  });

  it('rejects references not found in the current tenant', async () => {
    repo.tier.mockResolvedValue(null);
    await expect(service.updateReward(reward.id, { tierCode: 'FOREIGN', reason: 'Wrong tier' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_REWARD_TIER' });
    repo.rankExists.mockResolvedValue(false);
    await expect(service.updateReward(reward.id, { minRankId: 'rank', reason: 'Wrong rank' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_REWARD_RANK' });
  });

  it('rejects duplicate codes and SKUs', async () => {
    repo.tierCodeExists.mockResolvedValue(true);
    await expect(service.createTier(createTierBody.parse({ code: 'TEST', name: 'Tier', minMarks: 0 }), 'admin')).rejects.toMatchObject({ code: 'TIER_CODE_TAKEN' });
    repo.skuExists.mockResolvedValue(true);
    await expect(service.createReward(createRewardBody.parse({ sku: 'WRAPS', name: 'Wraps', marksCost: 80 }), 'admin')).rejects.toMatchObject({ code: 'REWARD_SKU_TAKEN' });
  });

  it('does not update, move stock or audit unchanged values/equivalent dates', async () => {
    reward.saleStartsAt = new Date('2026-10-01T00:00:00Z');
    await service.updateReward(reward.id, { stock: 10, saleStartsAt: '2026-10-01T07:00:00+07:00', reason: 'No changes' }, 'admin');
    expect(repo.updateReward).not.toHaveBeenCalled();
    expect(repo.inventory).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects missing rewards and tiers', async () => {
    repo.reward.mockResolvedValue(null);
    await expect(service.updateReward('missing', { name: 'Test', reason: 'Missing' }, 'admin')).rejects.toMatchObject({ status: 404 });
    repo.tier.mockResolvedValue(null);
    await expect(service.updateTier('MISSING', { name: 'Test', reason: 'Missing' }, 'admin')).rejects.toMatchObject({ status: 404 });
  });
});
