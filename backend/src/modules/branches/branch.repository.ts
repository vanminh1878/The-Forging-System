import { sql } from '../../db/sql';
import type { Branch, BranchInput } from './branch.types';

// An unset qr_version reads as '1' everywhere (single source of truth for the QR contract).
// numeric columns come back from pg as strings, so cast them for the API.
const COLUMNS = `id, code, name, address, opening_hours, latitude::float8 AS latitude, longitude::float8 AS longitude,
  geofence_radius_m, is_active, COALESCE(qr_version, '1') AS qr_version`;

export class BranchRepository {
  list(includeInactive: boolean): Promise<Array<Branch & { qrVersion: string | null }>> {
    return sql.many(`SELECT ${COLUMNS} FROM branches WHERE ($1 OR is_active) ORDER BY name, code`, [
      includeInactive,
    ]);
  }

  findById(id: string): Promise<(Branch & { qrVersion: string | null }) | null> {
    return sql.one(`SELECT ${COLUMNS} FROM branches WHERE id = $1`, [id]);
  }

  findByCode(code: string): Promise<{ id: string } | null> {
    return sql.one(`SELECT id FROM branches WHERE code = $1`, [code]);
  }

  insert(i: BranchInput & { code: string; name: string }): Promise<Branch & { qrVersion: string | null }> {
    return sql.one(
      `INSERT INTO branches (tenant_id, code, name, address, opening_hours, latitude, longitude, geofence_radius_m)
       VALUES (current_setting('app.current_tenant_id')::uuid, $1, $2, $3, $4, $5, $6, COALESCE($7, 100))
       RETURNING ${COLUMNS}`,
      [
        i.code,
        i.name,
        i.address ?? null,
        i.openingHours ?? null,
        i.latitude ?? null,
        i.longitude ?? null,
        i.geofenceRadiusM ?? null,
      ],
    ) as Promise<Branch & { qrVersion: string | null }>;
  }

  /** Updates only the keys present in `patch` (null clears a nullable column). */
  update(id: string, patch: BranchInput): Promise<(Branch & { qrVersion: string | null }) | null> {
    const cols: Record<keyof BranchInput, string> = {
      code: 'code',
      name: 'name',
      address: 'address',
      openingHours: 'opening_hours',
      latitude: 'latitude',
      longitude: 'longitude',
      geofenceRadiusM: 'geofence_radius_m',
    };
    const keys = (Object.keys(patch) as Array<keyof BranchInput>).filter((k) => patch[k] !== undefined);
    const sets = keys.map((k, n) => `${cols[k]} = $${n + 2}`);
    return sql.one(
      `UPDATE branches SET ${[...sets, 'updated_at = now()'].join(', ')} WHERE id = $1 RETURNING ${COLUMNS}`,
      [id, ...keys.map((k) => patch[k])],
    );
  }

  setActive(id: string, isActive: boolean): Promise<number> {
    return sql.exec(`UPDATE branches SET is_active = $2, updated_at = now() WHERE id = $1`, [id, isActive]);
  }

  /** Bumps qr_version (non-numeric/unset counts as 1) and fills qr_prefix when empty. Returns the new version. */
  bumpQrVersion(id: string, defaultPrefix: string): Promise<string | null> {
    return sql.scalar<string>(
      `UPDATE branches
          SET qr_version = (CASE WHEN COALESCE(qr_version, '1') ~ '^[0-9]{1,9}$' THEN COALESCE(qr_version, '1')::int + 1 ELSE 2 END)::text,
              qr_prefix = COALESCE(NULLIF(qr_prefix, ''), $2),
              updated_at = now()
        WHERE id = $1
        RETURNING qr_version`,
      [id, defaultPrefix],
    );
  }
}
