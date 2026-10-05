import 'dotenv/config';
import { db } from '../src/db/database';
import { env } from '../src/config/env';
import { lookupTenantByCode } from '../src/common/middlewares/tenant.middleware';
import { seedReferenceData } from '../src/seeds/reference-data';

async function main(): Promise<void> {
  const tenant = await lookupTenantByCode(env.DEFAULT_TENANT_CODE);
  await seedReferenceData(tenant.id);
  // eslint-disable-next-line no-console
  console.log(`reference data seeded for tenant "${tenant.code}"`);
  await db.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
