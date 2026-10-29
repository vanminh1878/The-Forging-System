import { conflict, notFound } from '../../common/errors/app-error';
import type { AuditService } from '../audit/audit.service';
import type { InventoryFilter, InventoryRepository } from './inventory.repository';

export class InventoryService {
  constructor(private readonly repo: InventoryRepository, private readonly audit: AuditService) {}

  history(filter: InventoryFilter, limit: number, offset: number) { return this.repo.history(filter, limit, offset); }

  async adjust(input: { rewardId: string; movementType: 'IN' | 'OUT'; quantity: number; reason: string }, actorId: string) {
    const reward = await this.repo.lockReward(input.rewardId);
    if (!reward) throw notFound('Reward');
    const stockAfter = reward.stock + (input.movementType === 'IN' ? input.quantity : -input.quantity);
    if (stockAfter < 0) throw conflict('Số lượng xuất vượt quá tồn kho khả dụng.', 'INSUFFICIENT_STOCK');
    if (stockAfter > 2_147_483_647) throw conflict('Tồn kho vượt giới hạn cho phép.', 'STOCK_LIMIT_EXCEEDED');
    await this.repo.setStock(input.rewardId, stockAfter);
    const movement = await this.repo.insert({ ...input, actorId });
    await this.audit.record({ actorId, action: input.movementType === 'IN' ? 'INVENTORY_IN' : 'INVENTORY_OUT',
      entityType: 'REWARD', entityId: reward.id, before: { stock: reward.stock },
      after: { stock: stockAfter, movement }, reason: input.reason });
    return { movement, stockBefore: reward.stock, stockAfter };
  }
}
