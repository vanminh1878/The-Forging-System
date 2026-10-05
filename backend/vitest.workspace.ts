import { defineWorkspace } from 'vitest/config';

// Two projects: fast unit tests (pure logic, no DB) and integration tests
// (real PostgreSQL, see docs/TESTING_GUIDE.md).
export default defineWorkspace([
  {
    test: {
      name: 'unit',
      include: ['tests/unit/**/*.test.ts'],
      environment: 'node',
    },
  },
  {
    test: {
      name: 'integration',
      include: ['tests/integration/**/*.test.ts'],
      environment: 'node',
      setupFiles: ['tests/helpers/integration-setup.ts'],
      globalSetup: ['tests/helpers/global-setup.ts'],
      // Integration tests share one database, so run all files in a single worker.
      pool: 'forks',
      poolOptions: { forks: { singleFork: true } },
      testTimeout: 30000,
      hookTimeout: 60000,
    },
  },
]);
