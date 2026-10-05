import type { Container } from '../container';

/** Handle returned by startScheduler so the server can stop jobs on shutdown. */
export interface Scheduler {
  stop(): void;
}

/** Placeholder replaced when the batch module registers its cron jobs. */
export function startScheduler(_container: Container): Scheduler {
  return { stop: () => undefined };
}
