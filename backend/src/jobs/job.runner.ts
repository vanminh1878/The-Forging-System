import { db } from '../db/database';
import { sql } from '../db/sql';
import { clock } from '../common/utils/clock';
import { logger } from '../common/utils/logger';
import type { AuditService } from '../modules/audit/audit.service';
import type { BatchJob, BatchRunRow, BatchRunStatus } from './job.types';

export const BATCH_RUN_COLUMNS = `id, batch_key, name, status, result_lines, run_by, started_at, run_at`;

/**
 * Runs one job for one tenant and records the outcome in batch_runs (never throws on job failure,
 * so the scheduler stays alive). One transaction per run: an advisory lock keyed by (job, tenant)
 * stops two processes running the same job at once (the loser records SKIPPED); the job itself runs
 * in a savepoint, so a failure rolls back its writes but still lets us record FAILED.
 */
export async function runJob(
  job: BatchJob,
  tenantId: string,
  runBy: string | null,
  audit: AuditService,
): Promise<BatchRunRow> {
  const startedAt = clock.now();
  return db.tenantTx(tenantId, async () => {
    let status: BatchRunStatus = 'SUCCESS';
    let lines: string[];
    const locked = await sql.scalar<boolean>(
      `SELECT pg_try_advisory_xact_lock(hashtext('batch:' || $1 || $2::text))`,
      [job.key, tenantId],
    );
    if (!locked) {
      status = 'SKIPPED';
      lines = ['Job đang chạy ở tiến trình khác.'];
    } else {
      try {
        lines = await db.nested(() => job.run({ tenantId, now: startedAt, runBy }));
      } catch (err) {
        logger.error({ err, job: job.key, tenantId }, 'batch job failed');
        status = 'FAILED';
        lines = [`Lỗi: ${err instanceof Error ? err.message : String(err)}`];
      }
    }
    const row = (await sql.one<BatchRunRow>(
      `INSERT INTO batch_runs (tenant_id, batch_key, name, status, result_lines, run_by, started_at)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7) RETURNING ${BATCH_RUN_COLUMNS}`,
      [tenantId, job.key, job.name, status, JSON.stringify(lines), runBy, startedAt],
    )) as BatchRunRow;
    await audit.record({
      actorId: runBy,
      action: 'BATCH_RUN',
      entityType: 'BATCH',
      entityId: row.id,
      after: { key: job.key, status, lines },
      reason: runBy ? 'Chạy thủ công' : 'Chạy theo lịch',
    });
    return row;
  });
}
