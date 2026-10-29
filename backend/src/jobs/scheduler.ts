import cron from 'node-cron';
import { env } from '../config/env';
import { lookupActiveTenantIds } from '../common/middlewares/tenant.middleware';
import { logger } from '../common/utils/logger';
import type { Container } from '../container';
import { runJob } from './job.runner';
import { jobs as registry } from './registry';
import type { BatchJob } from './job.types';

/** Handle returned by startScheduler so the server can stop jobs on shutdown. */
export interface Scheduler {
  stop(): void;
}

/** Schedules every job in the registry (timezone APP_TIMEZONE) and runs it for each active tenant. */
export function startScheduler(container: Container, jobs: BatchJob[] = registry): Scheduler {
  const tasks = jobs.map((job) =>
    cron.schedule(
      job.cron,
      () => {
        void (async () => {
          for (const tenant of await lookupActiveTenantIds()) {
            await runJob(job, tenant.id, null, container.services.audit).catch((err) =>
              logger.error({ err, job: job.key, tenant: tenant.code }, 'scheduled batch run failed'),
            );
          }
        })().catch((err) => logger.error({ err, job: job.key }, 'scheduler tick failed'));
      },
      { timezone: env.APP_TIMEZONE },
    ),
  );
  return { stop: () => tasks.forEach((t) => t.stop()) };
}
