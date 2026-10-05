import { afterAll } from 'vitest';
import { TEST_DATABASE_MIGRATE_URL, TEST_DATABASE_URL } from './test-env';

/*
 * Runs in every integration test file BEFORE application modules are imported,
 * so config/env picks up the test settings.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DATABASE_MIGRATE_URL = TEST_DATABASE_MIGRATE_URL;
process.env.JWT_ACCESS_SECRET = 'test-secret-test-secret-test-secret';
process.env.BCRYPT_ROUNDS = '4';
process.env.ENABLE_SCHEDULER = 'false';
process.env.LOG_LEVEL = 'silent';
process.env.UPLOAD_DIR = './uploads-test';
process.env.APP_TIMEZONE = 'Asia/Ho_Chi_Minh';

afterAll(async () => {
  const { db } = await import('../../src/db/database');
  await db.close();
});
