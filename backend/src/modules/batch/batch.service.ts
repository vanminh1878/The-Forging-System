import { notFound } from '../../common/errors/app-error';
import { db } from '../../db/database';
import { runJob } from '../../jobs/job.runner';
import type { BatchJob, BatchRunRow } from '../../jobs/job.types';
import type { AuditService } from '../audit/audit.service';
import type { BatchRepository, BatchRunFilter } from './batch.repository';

export class BatchService {
  constructor(
    private readonly repo: BatchRepository,
    private readonly audit: AuditService,
    private readonly jobs: BatchJob[],
  ) {}

  async listJobs() {
    const last = new Map((await this.repo.lastRuns(this.jobs.map((j) => j.key))).map((r) => [r.batchKey, r]));
    return this.jobs.map((j) => {
      const r = last.get(j.key);
      return {
        key: j.key,
        name: j.name,
        cron: j.cron,
        lastRun: r ? { status: r.status, runAt: r.runAt, lines: r.resultLines } : null,
      };
    });
  }

  /** Runs the job now for the current tenant; the run is recorded in batch_runs. */
  runNow(key: string, by: string): Promise<BatchRunRow> {
    const job = this.jobs.find((j) => j.key === key);
    if (!job) throw notFound('Batch job');
    return runJob(job, db.currentTenantId(), by, this.audit);
  }

  listRuns(filter: BatchRunFilter, limit: number, offset: number) {
    return this.repo.list(filter, limit, offset);
  }
}
