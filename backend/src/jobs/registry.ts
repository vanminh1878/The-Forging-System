import type { BatchJob } from './job.types';

/** Every scheduled job. Feature tasks push their job here (one entry each). */
export const jobs: BatchJob[] = [];

/** Adds a job, replacing any earlier job with the same key (the container is rebuilt in tests). */
export function registerJob(job: BatchJob): void {
  const i = jobs.findIndex((j) => j.key === job.key);
  if (i >= 0) jobs.splice(i, 1, job);
  else jobs.push(job);
}
