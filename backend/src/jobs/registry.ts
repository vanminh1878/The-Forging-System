import type { BatchJob } from './job.types';

/** Every scheduled job. Feature tasks push their job here (one entry each). */
export const jobs: BatchJob[] = [];
