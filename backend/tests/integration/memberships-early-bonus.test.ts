import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { env } from '../../src/config/env';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

const EVIDENCE = `${env.PUBLIC_BASE_URL}/files/evidence/abc.jpg`;

describe('early renewal bonus (MEM-05)', () => {
  let ctx: TestContext;
  let staff: string;
  let staffId: string;
  let book1: string;
  let book2: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const s = await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() } as never);
    staffId = s.userId;
    staff = (await login(ctx.api, s.phone)).token;
    const id = async (code: string) =>
      (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = $1`, [code]))[0].id;
    book1 = await id('BOOK_1');
    book2 = await id('BOOK_2');
  });
  afterEach(async () => {
    resetClock();
    await ctx.tx(() => ctx.services.settings.set('points.early_renewal_marks', 50, staffId));
  });

  const activate = (memberId: string, packageTypeId: string) =>
    ctx.api
      .post(`/api/v1/members/${memberId}/memberships`)
      .set(bearer(staff))
      .send({ packageTypeId, paymentEvidenceUrl: EVIDENCE });
  const marks = async (memberId: string) =>
    (await ownerQuery<{ marks_balance: number }>(`SELECT marks_balance FROM members WHERE user_id = $1`, [memberId]))[0]
      .marks_balance;
  const bonusRows = (memberId: string) =>
    ownerQuery<{ marks_amount: number; is_capped: boolean; membership_id: string }>(
      `SELECT marks_amount, is_capped, membership_id FROM point_transactions WHERE member_id = $1 AND source = 'EARLY_RENEWAL'`,
      [memberId],
    );

  it('awards +50 Marks (uncapped) when the new package is queued behind a valid one', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    const a = await activate(m.userId, book1);
    expect(a.body.data.bonusMarks).toBe(0);
    expect(await marks(m.userId)).toBe(0);

    const b = await activate(m.userId, book2);
    expect(b.body.data.mode).toBe('SCHEDULED');
    expect(b.body.data.bonusMarks).toBe(50);
    expect(b.body.data.message).toBe(
      'Gia hạn sớm: gói mới xếp nối tiếp từ 16/01/2027, học viên nhận +50 Marks (1 lần cho mỗi gói).',
    );
    expect(await marks(m.userId)).toBe(50);
    expect(await bonusRows(m.userId)).toEqual([
      { marks_amount: 50, is_capped: false, membership_id: b.body.data.membership.id },
    ]);
  });

  it('gives no bonus when the old package already expired (edge: last day still counts as early)', async () => {
    const m = await registerMember(ctx.api);
    await ownerQuery(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions)
       SELECT m.tenant_id, m.user_id, pt.id, '2026-07-01', '2026-10-23', 36 FROM members m, package_types pt
        WHERE m.user_id = $1 AND pt.code = 'BOOK_1'`,
      [m.userId],
    );
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const res = await activate(m.userId, book2);
    expect(res.body.data).toMatchObject({ mode: 'ACTIVATED', bonusMarks: 0 });
    expect(res.body.data.message).not.toContain('Marks');
    expect(await bonusRows(m.userId)).toHaveLength(0);
  });

  it('skips the bonus when points.early_renewal_marks is 0', async () => {
    setClock(fixedClock(new Date('2026-10-24T05:00:00Z')));
    const m = await registerMember(ctx.api);
    await activate(m.userId, book1);
    await ctx.tx(() => ctx.services.settings.set('points.early_renewal_marks', 0, staffId));
    const b = await activate(m.userId, book2);
    expect(b.body.data).toMatchObject({ mode: 'SCHEDULED', bonusMarks: 0 });
    expect(b.body.data.message).toBe('Gia hạn sớm: gói mới xếp nối tiếp từ 16/01/2027.');
    expect(await bonusRows(m.userId)).toHaveLength(0);
  });
});
