import 'dotenv/config';
import { runMigrations } from '../src/db/migrator';

async function main(): Promise<void> {
  const url = process.env.DATABASE_MIGRATE_URL ?? process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_MIGRATE_URL (or DATABASE_URL) is required');
  const res = await runMigrations(url);
  // eslint-disable-next-line no-console
  console.log(`migrations applied: ${res.applied.join(', ') || '(none)'}; already up to date: ${res.skipped.length}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
