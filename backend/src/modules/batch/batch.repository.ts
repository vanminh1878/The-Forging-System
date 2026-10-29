import { sql } from '../../db/sql';
import { BATCH_RUN_COLUMNS } from '../../jobs/job.runner';
import type { BatchRunRow } from '../../jobs/job.types';

export interface BatchRunFilter {
  key?: string;
  status?: string;
}

export class BatchRepository {
  /** Most recent run of each key in `keys` (batch_runs is append-only, so "last" = max run_at). */
  lastRuns(keys: string[]): Promise<BatchRunRow[]> {
    return sql.many(
      `SELECT DISTINCT ON (batch_key) ${BATCH_RUN_COLUMNS} FROM batch_runs
        WHERE batch_key = ANY($1::text[]) ORDER BY batch_key, run_at DESC, id`,
      [keys],
    );
  }

  async list(
    f: BatchRunFilter,
    limit: number,
    offset: number,
  ): Promise<{ rows: BatchRunRow[]; total: number }> {
    const where = `($1::text IS NULL OR batch_key = $1) AND ($2::text IS NULL OR status = $2)`;
    const params = [f.key ?? null, f.status ?? null];
    const rows = await sql.many<BatchRunRow>(
      `SELECT ${BATCH_RUN_COLUMNS} FROM batch_runs WHERE ${where} ORDER BY run_at DESC, id LIMIT $3 OFFSET $4`,
      [...params, limit, offset],
    );
    const total = await sql.scalar<number>(`SELECT COUNT(*)::int FROM batch_runs WHERE ${where}`, params);
    return { rows, total: total ?? 0 };
  }
}
