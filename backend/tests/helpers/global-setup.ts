import { Client } from 'pg';
import { runMigrations } from '../../src/db/migrator';
import { assertTestDatabase, TEST_DATABASE_MIGRATE_URL } from './test-env';

/** Runs once before all integration tests: rebuilds the schema from the migrations. */
export default async function globalSetup(): Promise<void> {
  assertTestDatabase(TEST_DATABASE_MIGRATE_URL);
  const client = new Client({ connectionString: TEST_DATABASE_MIGRATE_URL });
  await client.connect();
  try {
    await client.query('DROP SCHEMA IF EXISTS public CASCADE');
    await client.query('CREATE SCHEMA public');
    await client.query('GRANT ALL ON SCHEMA public TO public');
  } finally {
    await client.end();
  }
  await runMigrations(TEST_DATABASE_MIGRATE_URL);
}
