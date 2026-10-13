import 'dotenv/config';
import { lookupTenantByCode } from '../src/common/middlewares/tenant.middleware';
import { hashPassword, isStrongPassword } from '../src/common/utils/password';
import { isValidPhone, normalizePhone } from '../src/common/utils/phone';
import { env } from '../src/config/env';
import { db } from '../src/db/database';
import { sql } from '../src/db/sql';

/**
 * Creates the first ADMIN account (staff are provisioned by admins, so a fresh
 * database has nobody who could log in). Idempotent: an existing phone is left untouched.
 *
 *   docker compose --env-file .env.prod -f docker-compose.prod.yml exec \
 *     -e ADMIN_PHONE=09xxxxxxxx -e ADMIN_PASSWORD='...' -e ADMIN_NAME='Quản trị' api \
 *     npx tsx scripts/create-admin.ts
 */
async function main(): Promise<void> {
  const phone = normalizePhone(process.env.ADMIN_PHONE ?? '');
  const password = process.env.ADMIN_PASSWORD ?? '';
  const fullName = (process.env.ADMIN_NAME ?? 'Quản trị viên').trim();
  const email = process.env.ADMIN_EMAIL?.trim() || null;

  if (!isValidPhone(phone)) throw new Error('ADMIN_PHONE must be a 10-digit local number (0XXXXXXXXX).');
  if (!isStrongPassword(password, 10)) throw new Error('ADMIN_PASSWORD must have at least 10 characters, a letter and a digit.');

  const tenant = await lookupTenantByCode(env.DEFAULT_TENANT_CODE);
  const created = await db.tenantTx(tenant.id, async () => {
    if (await sql.scalar(`SELECT 1 FROM users WHERE phone = $1`, [phone])) return false;
    const user = await sql.one<{ id: string }>(
      `INSERT INTO users (tenant_id, email, phone, password_hash, full_name)
       VALUES ($1,$2,$3,$4,$5) RETURNING id`,
      [tenant.id, email, phone, await hashPassword(password), fullName],
    );
    await sql.exec(`INSERT INTO user_roles (tenant_id, user_id, role_code) VALUES ($1,$2,'ADMIN')`, [tenant.id, user!.id]);
    return true;
  });
  // eslint-disable-next-line no-console
  console.log(created ? `Admin created: ${phone}` : `Account ${phone} already exists - nothing changed.`);
  await db.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
