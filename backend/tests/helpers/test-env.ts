/**
 * Connection settings for integration tests. They always target a database
 * whose name ends with "_test" so a developer database is never wiped.
 */
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgres://hvp_app:hvp_app_pw@localhost:5432/hvp_test';
export const TEST_DATABASE_MIGRATE_URL =
  process.env.TEST_DATABASE_MIGRATE_URL ?? 'postgres://hvp_owner:hvp_owner_pw@localhost:5432/hvp_test';

export function assertTestDatabase(url: string): void {
  const name = new URL(url).pathname.replace('/', '');
  if (!name.endsWith('_test')) {
    throw new Error(`Refusing to run integration tests against "${name}": the database name must end with _test`);
  }
}
