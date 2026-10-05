import { sql } from '../../db/sql';

/** Small read-only lookup of user display data shared by many modules. */
export class UserDirectory {
  async displayName(userId: string): Promise<string> {
    const row = await sql.one<{ fullName: string }>(`SELECT full_name FROM users WHERE id = $1`, [userId]);
    return row?.fullName ?? 'Unknown';
  }

  /** Actor label used in audit texts: "HLV Name", "Lễ tân Name", "Admin - Name". */
  async actorLabel(userId: string, roles: readonly string[]): Promise<string> {
    const name = await this.displayName(userId);
    if (roles.includes('ADMIN') || roles.includes('SUPER_ADMIN')) return `Admin - ${name}`;
    if (roles.includes('COACH') || roles.includes('HEAD_COACH')) return `HLV ${name}`;
    if (roles.includes('RECEPTIONIST')) return `Lễ tân ${name}`;
    return name;
  }
}
