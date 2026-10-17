import { AsyncLocalStorage } from 'node:async_hooks';
import { Pool, types } from 'pg';
import type { PoolClient } from 'pg';
import { env } from '../config/env';
import { logger } from '../common/utils/logger';
import type { Queryable } from './types';

/*
 * Postgres type parsers: keep numbers as JS numbers and DATE columns as plain
 * 'YYYY-MM-DD' strings (no accidental timezone shifting).
 */
types.setTypeParser(20, (v) => Number(v)); // int8 / bigint identity
types.setTypeParser(1700, (v) => Number(v)); // numeric
types.setTypeParser(1082, (v) => v); // date

type AfterCommitHook = () => Promise<void> | void;

interface TenantStore {
  client: PoolClient;
  tenantId: string;
  afterCommit: AfterCommitHook[];
  savepointSeq: number;
}

const storage = new AsyncLocalStorage<TenantStore>();

/**
 * Thin wrapper around pg.Pool that provides:
 *  - tenantTx(): one transaction per unit of work with the PostgreSQL setting
 *    `app.current_tenant_id` applied, so row level security isolates tenants;
 *  - an AsyncLocalStorage context so repositories never receive a client
 *    explicitly (see db/sql.ts);
 *  - afterCommit hooks for side effects (push notifications) that must only
 *    happen once the transaction is durable.
 */
export class Database {
  readonly pool: Pool;

  constructor(connectionString: string = env.DATABASE_URL) {
    this.pool = new Pool({ connectionString, max: 10 });
    this.pool.on('error', (err) => logger.error({ err }, 'unexpected idle pg client error'));
  }

  /** Runs `fn` inside a tenant-scoped transaction (joins an existing one for the same tenant). */
  async tenantTx<T>(tenantId: string, fn: () => Promise<T>): Promise<T> {
    const existing = storage.getStore();
    if (existing) {
      if (existing.tenantId !== tenantId) {
        throw new Error('Cannot open a transaction for another tenant inside an active transaction');
      }
      return fn();
    }

    const client = await this.pool.connect();
    const store: TenantStore = { client, tenantId, afterCommit: [], savepointSeq: 0 };
    try {
      await client.query('BEGIN');
      await client.query("SELECT set_config('app.current_tenant_id', $1, true)", [tenantId]);
      const result = await storage.run(store, fn);
      await client.query('COMMIT');
      this.runAfterCommit(store);
      return result;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Runs `fn` inside a SAVEPOINT of the current transaction: if it throws, only
   * its own writes are rolled back. Used by batch jobs to isolate one member's
   * failure from the rest of the run.
   */
  async nested<T>(fn: () => Promise<T>): Promise<T> {
    const store = this.requireStore();
    const name = `sp_${++store.savepointSeq}`;
    await store.client.query(`SAVEPOINT ${name}`);
    try {
      const out = await fn();
      await store.client.query(`RELEASE SAVEPOINT ${name}`);
      return out;
    } catch (err) {
      await store.client.query(`ROLLBACK TO SAVEPOINT ${name}`);
      throw err;
    }
  }

  /**
   * Runs `fn` in its own transaction for the current tenant, committed even if
   * the caller's transaction later rolls back (e.g. counting a failed PIN attempt
   * right before throwing).
   */
  detachedTx<T>(fn: () => Promise<T>): Promise<T> {
    const tenantId = this.currentTenantId();
    return storage.exit(() => this.tenantTx(tenantId, fn));
  }

  /** Registers a side effect to run only after the current transaction commits. */
  afterCommit(hook: AfterCommitHook): void {
    this.requireStore().afterCommit.push(hook);
  }

  /** Pool-level access for work that is not tenant scoped (tenant lookup, migrations). */
  get system(): Queryable {
    return this.pool;
  }

  /** Current transactional client; throws when called outside tenantTx(). */
  current(): PoolClient {
    return this.requireStore().client;
  }

  currentTenantId(): string {
    return this.requireStore().tenantId;
  }

  hasContext(): boolean {
    return storage.getStore() !== undefined;
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  private requireStore(): TenantStore {
    const store = storage.getStore();
    if (!store) throw new Error('No active tenant transaction. Wrap the call in db.tenantTx().');
    return store;
  }

  private runAfterCommit(store: TenantStore): void {
    for (const hook of store.afterCommit) {
      Promise.resolve()
        .then(hook)
        .catch((err) => logger.error({ err }, 'afterCommit hook failed'));
    }
  }
}

export const db = new Database();
