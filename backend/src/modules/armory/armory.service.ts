import { clock } from '../../common/utils/clock';
import type { ArmoryRepository, RewardFilter } from './armory.repository';

export class ArmoryService {
  constructor(private readonly repo: ArmoryRepository) {}

  tiers() { return this.repo.tiers(); }

  async rewards(filter: RewardFilter, limit: number, offset: number) {
    const result = await this.repo.rewards(filter, clock.now(), limit, offset);
    return { ...result, items: result.items.map((item) => ({ ...item, inStock: item.stock > 0 })) };
  }
}
