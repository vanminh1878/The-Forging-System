import { badRequest, notFound } from '../../common/errors/app-error';
import { db } from '../../db/database';
import { sql } from '../../db/sql';
import { CONFIG_BY_KEY, CONFIG_CATALOG } from './settings.catalog';
import type { ConfigDefinition, ConfigGroup } from './settings.catalog';
import { validateConfigValue } from './settings.validation';

interface ConfigRow {
  key: string;
  value: unknown;
  updatedAt: Date;
  updatedBy: string | null;
}

export interface ConfigEntry extends ConfigDefinition {
  value: unknown;
  isDefault: boolean;
  updatedAt: Date | null;
  updatedBy: string | null;
}

export class SettingsService {
  async get<T = number>(key: string): Promise<T> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw new Error(`Unknown config key "${key}"`);
    // A pooled client is reused across requests/tenants; never retain a cache on it.
    const row = await sql.one<ConfigRow>('SELECT key,value FROM system_configs WHERE key=$1', [key]);
    return (row ? row.value : def.defaultValue) as T;
  }

  async getNumber(key: string): Promise<number> {
    return Number(await this.get<number>(key));
  }

  async getBool(key: string): Promise<boolean> {
    return Boolean(await this.get<boolean>(key));
  }

  /** Every catalog entry merged with the tenant's overrides (admin screen). */
  async listAll(filter: { group?: ConfigGroup; q?: string } = {}): Promise<ConfigEntry[]> {
    const rows = await sql.many<ConfigRow>('SELECT key, value, updated_at, updated_by FROM system_configs');
    const byKey = new Map(rows.map((r) => [r.key, r]));
    const q = filter.q?.toLowerCase();
    return CONFIG_CATALOG.filter((d) => (!filter.group || d.group === filter.group) &&
      (!q || d.key.toLowerCase().includes(q) || d.description.toLowerCase().includes(q))).map((d) => {
      const row = byKey.get(d.key);
      return { ...d, value: row ? row.value : d.defaultValue, isDefault: !row, updatedAt: row?.updatedAt ?? null, updatedBy: row?.updatedBy ?? null };
    });
  }

  async entry(key: string): Promise<ConfigEntry> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw notFound('Config');
    const row = await sql.one<ConfigRow>('SELECT key,value,updated_at,updated_by FROM system_configs WHERE key=$1', [key]);
    return { ...def, value: row ? row.value : def.defaultValue, isDefault: !row, updatedAt: row?.updatedAt ?? null, updatedBy: row?.updatedBy ?? null };
  }

  async history(key: string, limit = 50): Promise<Array<{ id: number; action: string; beforeData: unknown; afterData: unknown; reason: string | null; actorId: string | null; createdAt: Date }>> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw notFound('Config');
    return sql.many(`SELECT id, action, before_data, after_data, reason, actor_id, created_at
      FROM audit_logs WHERE entity_type='SYSTEM_CONFIG' AND entity_id=$1
      ORDER BY created_at DESC, id DESC LIMIT $2`, [key, limit]);
  }

  async rollback(key: string, versionId: number, actorId: string | null, reason: string): Promise<void> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw notFound('Config');
    const row = await sql.one<{ beforeData: unknown; afterData: unknown }>(
      `SELECT before_data, after_data FROM audit_logs WHERE id=$1 AND entity_type='SYSTEM_CONFIG' AND entity_id=$2`,
      [versionId, key],
    );
    if (!row) throw notFound('Config version');
    const target = row.afterData !== null && row.afterData !== undefined ? row.afterData : row.beforeData;
    if (target === null || target === undefined) throw badRequest('Selected config version has no value to restore.', undefined, 'INVALID_CONFIG_VERSION');
    await this.set(key, target, actorId, reason);
  }

  /**
   * Upserts a parameter. The DB trigger fn_system_configs_audit records the
   * before/after value in audit_logs on insert or value changes (migration 0005).
   */
  async set(key: string, value: unknown, actorId: string | null, reason?: string): Promise<void> {
    const def = CONFIG_BY_KEY.get(key);
    if (!def) throw badRequest(`Unknown config key "${key}"`, undefined, 'UNKNOWN_CONFIG_KEY');
    validateConfigValue(def, value);
    if (reason !== undefined && (reason.trim().length < 3 || reason.trim().length > 500)) throw badRequest('Reason must contain 3–500 characters.');
    await sql.exec(`SELECT set_config('app.config_change_reason',$1,true)`, [reason?.trim() ?? '']);
    await sql.exec(
      `INSERT INTO system_configs (tenant_id, key, config_group, value, value_type, description, updated_by)
       VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7)
       ON CONFLICT (tenant_id, key) DO UPDATE
          SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()
          WHERE system_configs.value IS DISTINCT FROM EXCLUDED.value`,
      [db.currentTenantId(), key, def.group, JSON.stringify(value), def.type, def.description, actorId],
    );
  }
}
