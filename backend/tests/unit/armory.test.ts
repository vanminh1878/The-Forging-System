import { afterEach, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { ArmoryService } from '../../src/modules/armory/armory.service';
import type { ArmoryRepository } from '../../src/modules/armory/armory.repository';

describe('ARM-01 catalogue', () => {
  afterEach(resetClock);

  it('uses the server clock and exposes availability without hiding empty stock', async () => {
    const now = new Date('2026-10-15T12:00:00Z');
    setClock(fixedClock(now));
    const repo = { rewards: vi.fn().mockResolvedValue({ items: [{ id: 'one', stock: 2 }, { id: 'two', stock: 0 }], total: 2 }) };
    const service = new ArmoryService(repo as unknown as ArmoryRepository);
    const result = await service.rewards({ tierCode: 'FIELD_SUPPLIES' }, 20, 0);
    expect(repo.rewards).toHaveBeenCalledWith({ tierCode: 'FIELD_SUPPLIES' }, now, 20, 0);
    expect(result.items.map((item) => item.inStock)).toEqual([true, false]);
    expect(result.total).toBe(2);
  });

  it('returns an empty catalogue unchanged', async () => {
    const repo = { rewards: vi.fn().mockResolvedValue({ items: [], total: 0 }) };
    expect(await new ArmoryService(repo as unknown as ArmoryRepository).rewards({}, 20, 0)).toEqual({ items: [], total: 0 });
  });
});
