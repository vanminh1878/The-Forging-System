import { hashPassword } from '../common/utils/password';
import { db } from '../db/database';
import { sql } from '../db/sql';
import type { Container } from '../container';

/** Password of every demo account (development only - never run this seed in production). */
export const DEMO_PASSWORD = 'hvp12345';

interface DemoStaff {
  fullName: string;
  phone: string;
  email: string;
  role: 'ADMIN' | 'HEAD_COACH' | 'COACH' | 'RECEPTIONIST';
  branchCode: string;
}

interface DemoMember {
  fullName: string;
  phone: string;
  email: string;
  /** Opening DP balance (posted as an OPENING ledger row). */
  dp: number;
  marks: number;
  /** How long ago the member joined, in days (drives the rank time-gate). */
  joinedDaysAgo: number;
  branchCode: string;
}

const STAFF: DemoStaff[] = [
  { fullName: 'Quản Trị Demo', phone: '0900000001', email: 'admin@demo.hvp', role: 'ADMIN', branchCode: 'Q1' },
  { fullName: 'Head Coach Demo', phone: '0900000002', email: 'headcoach@demo.hvp', role: 'HEAD_COACH', branchCode: 'Q1' },
  { fullName: 'Coach Demo', phone: '0900000003', email: 'coach@demo.hvp', role: 'COACH', branchCode: 'Q7' },
  { fullName: 'Lễ Tân Demo', phone: '0900000004', email: 'reception@demo.hvp', role: 'RECEPTIONIST', branchCode: 'Q1' },
];

const MEMBERS: DemoMember[] = [
  { fullName: 'Học Viên Mới', phone: '0911000001', email: 'new@demo.hvp', dp: 0, marks: 0, joinedDaysAgo: 0, branchCode: 'Q1' },
  { fullName: 'Học Viên Đang Tập', phone: '0911000002', email: 'active@demo.hvp', dp: 620, marks: 85, joinedDaysAgo: 45, branchCode: 'Q1' },
  { fullName: 'Học Viên Gần Lên Hạng', phone: '0911000003', email: 'near@demo.hvp', dp: 2420, marks: 140, joinedDaysAgo: 120, branchCode: 'Q7' },
  { fullName: 'Học Viên Kỳ Cựu', phone: '0911000004', email: 'veteran@demo.hvp', dp: 5400, marks: 320, joinedDaysAgo: 240, branchCode: 'Q7' },
];

/**
 * Development fixtures: one staff account per role and a few learners at different
 * stages of the rank ladder. Idempotent - existing phone numbers are skipped.
 * Only uses the foundation services, so it keeps working as feature modules are added.
 */
export async function seedDemoData(tenantId: string, container: Container): Promise<{ created: string[] }> {
  const created: string[] = [];
  await db.tenantTx(tenantId, async () => {
    const passwordHash = await hashPassword(DEMO_PASSWORD);

    for (const s of STAFF) {
      if (await sql.scalar(`SELECT 1 FROM users WHERE phone = $1`, [s.phone])) continue;
      const user = await sql.one<{ id: string }>(
        `INSERT INTO users (tenant_id, email, phone, password_hash, full_name, branch_id)
         VALUES ($1,$2,$3,$4,$5,(SELECT id FROM branches WHERE code = $6)) RETURNING id`,
        [tenantId, s.email, s.phone, passwordHash, s.fullName, s.branchCode],
      );
      await sql.exec(`INSERT INTO user_roles (tenant_id, user_id, role_code) VALUES ($1,$2,$3)`, [tenantId, user!.id, s.role]);
      created.push(`${s.role}: ${s.phone}`);
    }

    for (const m of MEMBERS) {
      if (await sql.scalar(`SELECT 1 FROM users WHERE phone = $1`, [m.phone])) continue;
      const branchId = await sql.scalar<string>(`SELECT id FROM branches WHERE code = $1`, [m.branchCode]);
      const { userId } = await container.services.members.createMember({
        fullName: m.fullName,
        phone: m.phone,
        email: m.email,
        password: DEMO_PASSWORD,
        homeBranchId: branchId ?? undefined,
      });
      await sql.exec(`UPDATE members SET joined_at = now() - ($2 || ' days')::interval WHERE user_id = $1`, [userId, String(m.joinedDaysAgo)]);
      if (m.dp > 0 || m.marks > 0) {
        await container.services.points.award({
          memberId: userId,
          source: 'OPENING',
          dp: m.dp,
          marks: m.marks,
          note: 'Số dư khởi tạo (demo)',
          idempotencyKey: `demo-opening:${userId}`,
        });
      }
      created.push(`MEMBER: ${m.phone}`);
    }
  });
  return { created };
}
