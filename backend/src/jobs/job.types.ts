export interface BatchJobContext {
  tenantId: string;
  now: Date;
  /** Admin who triggered the run; null when started by the scheduler. */
  runBy: string | null;
}

/** A scheduled, idempotent unit of work. `run` executes inside the tenant transaction. */
export interface BatchJob {
  /** Stable key stored in batch_runs.batch_key. */
  key: string;
  /** Vietnamese display name. */
  name: string;
  cron: string;
  /** Returns the result lines shown to admins. */
  run(ctx: BatchJobContext): Promise<string[]>;
}

export type BatchRunStatus = 'SUCCESS' | 'FAILED' | 'SKIPPED';

export interface BatchRunRow {
  id: string;
  batchKey: string;
  name: string;
  status: BatchRunStatus;
  resultLines: string[];
  runBy: string | null;
  startedAt: string | null;
  runAt: string;
}
