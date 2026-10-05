import type { QueryResult, QueryResultRow } from 'pg';

/** Minimal query surface shared by Pool and PoolClient. */
export interface Queryable {
  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>>;
}
