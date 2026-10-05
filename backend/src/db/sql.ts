import type { QueryResultRow } from 'pg';
import { db } from './database';

/** snake_case -> camelCase for the top-level keys of a row (JSONB payloads are left untouched). */
function camelKey(key: string): string {
  return key.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase());
}

export function camelizeRow<T>(row: QueryResultRow): T {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) out[camelKey(k)] = v;
  return out as T;
}

/**
 * Query helpers bound to the current tenant transaction. Repositories use these
 * instead of touching pg directly, so every statement runs under RLS.
 */
export const sql = {
  /** Returns all rows, camelCased. */
  async many<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
    const res = await db.current().query(text, params);
    return res.rows.map((r) => camelizeRow<T>(r));
  },

  /** Returns the first row or null. */
  async one<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T | null> {
    const rows = await sql.many<T>(text, params);
    return rows[0] ?? null;
  },

  /** Returns the first column of the first row (e.g. COUNT/SUM) or null. */
  async scalar<T = number>(text: string, params: unknown[] = []): Promise<T | null> {
    const res = await db.current().query({ text, values: params, rowMode: 'array' });
    return (res.rows[0]?.[0] as T | undefined) ?? null;
  },

  /** Executes a statement and returns the affected row count. */
  async exec(text: string, params: unknown[] = []): Promise<number> {
    const res = await db.current().query(text, params);
    return res.rowCount ?? 0;
  },
};
