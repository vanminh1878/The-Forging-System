import type { PoolClient } from 'pg';
import { badRequest } from '../../common/errors/app-error';
import { db } from '../../db/database';
import { sql } from '../../db/sql';
import { CONFIG_BY_KEY, CONFIG_CATALOG } from './settings.catalog';
import type { ConfigDefinition } from './settings.catalog';

interface ConfigRow {
  key: string;
  value: unknown;
  updatedAt: Date;
  updatedBy: string | null;
}

// Per-transaction cache so a request reading many parameters hits the DB once.
const cache = new WeakMap<PoolClient, Map<string, unknown>>();

export interface ConfigEntry extends ConfigDefinition {
  value: unknown;
  isDefault: boolean;
  updatedAt: Date | null;
}

export class SettingsService {
  private async load(): Promise<Map<string, unknown>> {
    const client = db.current();
    const hit = cache.get(client);
    if (hit) return hit;
    const rows = await sql.many<ConfigRow>('SELECT key, value FROM system_configs');
    const map = new Map(rows.map((r) => [r.key, r.value]));
    cache.set(client, map);
    return map;
  }

  async get<T = number>(key: string): Promise<T> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw new Error(`Unknown config key "${key}"`);
    const map = await this.load();
    return (map.has(key) ? map.get(key) : def.defaultValue) as T;
  }

  async getNumber(key: string): Promise<number> {
    return Number(await this.get<number>(key));
  }

  async getBool(key: string): Promise<boolean> {
    return Boolean(await this.get<boolean>(key));
  }

  /** Every catalog entry merged with the tenant's overrides (admin screen). */
  async listAll(): Promise<ConfigEntry[]> {
    const rows = await sql.many<ConfigRow>('SELECT key, value, updated_at, updated_by FROM system_configs');
    const byKey = new Map(rows.map((r) => [r.key, r]));
    return CONFIG_CATALOG.map((d) => {
      const row = byKey.get(d.key);
      return { ...d, value: row ? row.value : d.defaultValue, isDefault: !row, updatedAt: row?.updatedAt ?? null };
    });
  }

  /**
   * Upserts a parameter. The DB trigger fn_system_configs_audit records the
   * before/after value in audit_logs when an existing row changes.
   */
  async set(key: string, value: unknown, actorId: string | null): Promise<void> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw badRequest(`Unknown config key "${key}"`);
    this.validate(def, value);
    await sql.exec(
      `INSERT INTO system_configs (tenant_id, key, config_group, value, value_type, description, updated_by)
       VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7)
       ON CONFLICT (tenant_id, key) DO UPDATE
         SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [db.currentTenantId(), key, def.group, JSON.stringify(value), def.type, def.description, actorId],
    );
    cache.delete(db.current());
  }

  private validate(def: ConfigDefinition, value: unknown): void {
    switch (def.type) {
      case 'INT':
      case 'DECIMAL': {
        if (typeof value !== 'number' || Number.isNaN(value)) throw badRequest(`"${def.key}" must be a number`);
        if (def.min !== undefined && value < def.min) throw badRequest(`"${def.key}" must be >= ${def.min}`);
        if (def.max !== undefined && value > def.max) throw badRequest(`"${def.key}" must be <= ${def.max}`);
        if (def.type === 'INT' && !Number.isInteger(value)) throw badRequest(`"${def.key}" must be an integer`);
        break;
      }
      case 'BOOL':
        if (typeof value !== 'boolean') throw badRequest(`"${def.key}" must be a boolean`);
        break;
      default:
        break;
    }
  }
}
