import { sql } from '../../db/sql';
import type { Branch } from './branch.types';

// numeric columns come back from pg as strings, so cast them for the API.
const COLUMNS = `id, code, name, address, opening_hours, latitude::float8 AS latitude, longitude::float8 AS longitude,
  geofence_radius_m, is_active, qr_version`;

export class BranchRepository {
  list(includeInactive: boolean): Promise<Array<Branch & { qrVersion: string | null }>> {
    return sql.many(`SELECT ${COLUMNS} FROM branches WHERE ($1 OR is_active) ORDER BY name, code`, [
      includeInactive,
    ]);
  }

  findById(id: string): Promise<(Branch & { qrVersion: string | null }) | null> {
    return sql.one(`SELECT ${COLUMNS} FROM branches WHERE id = $1`, [id]);
  }
}
