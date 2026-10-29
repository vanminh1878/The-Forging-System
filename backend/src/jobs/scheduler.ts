import type { Container } from '../container';
import cron from 'node-cron';
import { logger } from '../common/utils/logger';
import { db } from '../db/database';

/** Handle returned by startScheduler so the server can stop jobs on shutdown. */
export interface Scheduler {
  stop(): void;
}

/** Minimal periodic jobs currently implemented before the general Batch module lands. */
export function startScheduler(container: Container): Scheduler {
  const armoryExpiry = cron.schedule('*/15 * * * *', () => {
    void expireArmoryPickups(container).catch((err) => logger.error({ err }, 'armory pickup expiry job failed'));
  });
  return { stop: () => armoryExpiry.stop() };
}

/** Run expiry inside each tenant transaction; stale-order candidates are rechecked under row locks. */
export async function expireArmoryPickups(container: Container): Promise<number> {
  const tenants = await db.system.query<{ id: string }>(`SELECT id FROM tenants WHERE is_active=true ORDER BY id`);
  let expired = 0;
  for (const tenant of tenants.rows) {
    expired += await db.tenantTx(tenant.id, async () => (await container.services.redemptions.expirePending()).expired);
  }
  return expired;
}
