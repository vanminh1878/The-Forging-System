import 'dotenv/config';
import { buildContainer } from '../src/container';
import { lookupTenantByCode } from '../src/common/middlewares/tenant.middleware';
import { env } from '../src/config/env';
import { db } from '../src/db/database';
import { DEMO_PASSWORD, seedDemoData } from '../src/seeds/demo-data';

async function main(): Promise<void> {
  if (env.NODE_ENV === 'production') throw new Error('Refusing to seed demo accounts in production.');
  const tenant = await lookupTenantByCode(env.DEFAULT_TENANT_CODE);
  const { created } = await seedDemoData(tenant.id, buildContainer());
  // eslint-disable-next-line no-console
  console.log(created.length ? `Demo accounts created (password "${DEMO_PASSWORD}"):\n  ${created.join('\n  ')}` : 'Demo data already present.');
  await db.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
