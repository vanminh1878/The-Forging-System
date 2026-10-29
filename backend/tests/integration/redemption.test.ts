import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { sql } from '../../src/db/sql';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';
import type { CreateRedemptionInput } from '../../src/modules/armory/redemption.validation';

describe('ARM-02 redemption API', () => {
  let ctx: TestContext;
  let memberId: string;
  let token: string;
  let rewardId: string;
  let q1: string;
  let q7: string;
  const path = '/api/v1/armory/redemptions';

  beforeAll(async () => {
    ctx = await bootTestApp();
    await ctx.tx(async () => {
      q1 = (await sql.scalar<string>(`SELECT id FROM branches WHERE code='Q1'`))!;
      q7 = (await sql.scalar<string>(`SELECT id FROM branches WHERE code='Q7'`))!;
    });
  });
  beforeEach(async () => {
    const member = await registerMember(ctx.api);
    memberId = member.userId; token = member.token;
    await ctx.tx(async () => {
      await ctx.services.points.award({ memberId, source: 'OPENING', marks: 300, note: 'Opening test wallet' });
      await sql.exec('UPDATE members SET home_branch_id=$2 WHERE user_id=$1', [memberId, q1]);
      await sql.exec('UPDATE branches SET is_active=true WHERE id=$1', [q7]);
    });
    rewardId = await newReward();
  });
  afterEach(resetClock);

  async function newReward(cost = 120, stock = 3) {
    return ctx.tx(async () => (await sql.scalar<string>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock)
      VALUES ($1,$2,'Test Armory gift',$3,$4) RETURNING id`, [ctx.tenantId, randomUUID(), cost, stock]))!);
  }
  const body = (patch: Record<string, unknown> = {}): CreateRedemptionInput => ({ rewardId, pickupBranchId: q7, idempotencyKey: randomUUID(), ...patch });
  const post = (payload = body(), auth = token) => ctx.api.post(path).set(bearer(auth)).set('X-Tenant-Code', 'hvp').send(payload);
  const stock = (id = rewardId) => ctx.tx(() => sql.scalar<number>('SELECT stock FROM rewards WHERE id=$1', [id]));

  it('creates a pending order at another branch, holds Marks and reduces stock without posting a debit', async () => {
    const response = await post();
    expect(response.status).toBe(201);
    expect(response.body.data).toMatchObject({ duplicate: false, redemption: { rewardId, pickupBranchId: q7, marksCost: 120, status: 'PENDING_PICKUP' },
      wallet: { marksBalance: 300, marksHeld: 120, marksAvailable: 180 } });
    expect(response.body.data.redemption.redemptionCode).toMatch(/^ARM-/);
    expect(await stock()).toBe(2);
    const id = response.body.data.redemption.id;
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM point_transactions WHERE member_id=$1', [memberId]))).toBe(1);
    expect(await ctx.tx(() => sql.one('SELECT movement_type,quantity,actor_id FROM inventory_movements WHERE redemption_id=$1', [id]))).toEqual({ movementType: 'OUT', quantity: 1, actorId: memberId });
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT count(*)::int FROM audit_logs WHERE entity_id=$1 AND action='REDEMPTION_CREATED'`, [id]))).toBe(1);
  });

  it('accepts a simple two-field payload and generates separate internal request keys', async () => {
    const simple = { rewardId, pickupBranchId: q7 };
    const first = await post(simple);
    const second = await post(simple);
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    expect(first.body.data.redemption.id).not.toBe(second.body.data.redemption.id);
    expect(second.body.data.wallet).toMatchObject({ marksBalance: 300, marksHeld: 240, marksAvailable: 60 });
    expect(await stock()).toBe(1);
  });

  it('replays concurrent/repeated requests without double holds or stock changes', async () => {
    const payload = body();
    const results = await Promise.all([post(payload), post(payload)]);
    expect(results.map((result) => result.status).sort()).toEqual([200, 201]);
    expect(results[0].body.data.redemption.id).toBe(results[1].body.data.redemption.id);
    await ctx.tx(() => sql.exec('UPDATE rewards SET marks_cost=200,is_active=false WHERE id=$1', [rewardId]));
    const repeated = await post({ rewardId: rewardId.toUpperCase(), pickupBranchId: q7.toUpperCase(), idempotencyKey: payload.idempotencyKey!.toUpperCase() });
    expect(repeated.status).toBe(200);
    expect(repeated.body.data.redemption.marksCost).toBe(120);
    expect(repeated.body.data.wallet.marksHeld).toBe(120);
    expect(await stock()).toBe(2);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [rewardId]))).toBe(1);
  });

  it('rejects key reuse for different payloads but scopes keys to each learner', async () => {
    const payload = body();
    await post(payload).expect(201);
    expect((await post({ ...payload, pickupBranchId: q1 })).body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    const other = await registerMember(ctx.api);
    await ctx.tx(() => ctx.services.points.award({ memberId: other.userId, source: 'OPENING', marks: 300, note: 'Opening' }));
    await post(payload, other.token).expect(201);
    expect(await stock()).toBe(1);
  });

  it('serializes two learners competing for the final stock item', async () => {
    await ctx.tx(() => sql.exec('UPDATE rewards SET stock=1 WHERE id=$1', [rewardId]));
    const other = await registerMember(ctx.api);
    await ctx.tx(() => ctx.services.points.award({ memberId: other.userId, source: 'OPENING', marks: 300, note: 'Opening' }));
    const responses = await Promise.all([post(), post(body(), other.token)]);
    expect(responses.map((response) => response.status).sort()).toEqual([201, 409]);
    expect(responses.find((response) => response.status === 409)!.body.error.code).toBe('OUT_OF_STOCK');
    expect(await stock()).toBe(0);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM redemptions WHERE reward_id=$1', [rewardId]))).toBe(1);
  });

  it('prevents concurrent different gifts from overspending the same available Marks', async () => {
    const first = await newReward(200);
    const second = await newReward(200);
    const responses = await Promise.all([post(body({ rewardId: first })), post(body({ rewardId: second }))]);
    expect(responses.map((response) => response.status).sort()).toEqual([201, 422]);
    expect(responses.find((response) => response.status === 422)!.body.error.code).toBe('INSUFFICIENT_AVAILABLE_MARKS');
    expect((await stock(first))! + (await stock(second))!).toBe(5);
    expect(await ctx.tx(() => sql.scalar<number>(`SELECT SUM(marks_cost) FROM redemptions WHERE member_id=$1 AND status='PENDING_PICKUP'`, [memberId]))).toBe(200);
  });

  it('checks pickup branch, inactive/disabled member, sale windows and rank before mutation', async () => {
    expect((await post(body({ pickupBranchId: randomUUID() }))).body.error.code).toBe('INVALID_PICKUP_BRANCH');
    await ctx.tx(() => sql.exec('UPDATE branches SET is_active=false WHERE id=$1', [q7]));
    expect((await post()).body.error.code).toBe('INVALID_PICKUP_BRANCH');
    await ctx.tx(() => sql.exec('UPDATE branches SET is_active=true WHERE id=$1', [q7]));
    await ctx.tx(() => sql.exec(`UPDATE members SET status='INACTIVE',status_since=now() WHERE user_id=$1`, [memberId]));
    expect((await post()).body.error.code).toBe('MEMBER_INACTIVE');
    await ctx.tx(() => sql.exec(`UPDATE members SET status='FROZEN' WHERE user_id=$1`, [memberId]));
    await ctx.tx(() => sql.exec(`UPDATE users SET account_status='LOCKED' WHERE id=$1`, [memberId]));
    expect((await post()).body.error.code).toBe('ACCOUNT_DISABLED');
    await ctx.tx(() => sql.exec(`UPDATE users SET account_status='ACTIVE' WHERE id=$1`, [memberId]));
    setClock(fixedClock(new Date('2026-10-15T12:00:00Z')));
    await ctx.tx(() => sql.exec(`UPDATE rewards SET sale_starts_at='2026-10-16T00:00:00Z' WHERE id=$1`, [rewardId]));
    expect((await post()).body.error.code).toBe('REWARD_UNAVAILABLE');
    await ctx.tx(() => sql.exec(`UPDATE rewards SET sale_starts_at=NULL,sale_ends_at='2026-10-15T12:00:00Z' WHERE id=$1`, [rewardId]));
    expect((await post()).body.error.code).toBe('REWARD_UNAVAILABLE');
    const rank = await ctx.tx(() => sql.scalar<string>('SELECT id FROM ranks WHERE rank_order=2'));
    await ctx.tx(() => sql.exec('UPDATE rewards SET sale_ends_at=NULL,min_rank_id=$2 WHERE id=$1', [rewardId, rank]));
    expect((await post()).body.error.code).toBe('RANK_REQUIRED');
    await ctx.tx(() => sql.exec('UPDATE members SET current_rank_id=$2 WHERE user_id=$1', [memberId, rank]));
    await post().expect(201); // FROZEN is redeemable under runtime schema v3.
    expect(await stock()).toBe(2);
  });

  it('enforces monthly limits in local time and counts pending plus delivered orders only', async () => {
    setClock(fixedClock(new Date('2026-10-31T18:00:00Z'))); // 01/11 in Vietnam.
    await ctx.tx(async () => {
      await sql.exec(`UPDATE rewards SET per_member_limit=1,limit_period='MONTH' WHERE id=$1`, [rewardId]);
      await sql.exec(`INSERT INTO redemptions (tenant_id,redemption_code,member_id,reward_id,pickup_branch_id,marks_cost,idempotency_key,status,requested_at)
        VALUES ($1,$2,$3,$4,$5,120,$6,'DELIVERED','2026-10-31T16:59:00Z')`, [ctx.tenantId, randomUUID(), memberId, rewardId, q7, randomUUID()]);
    });
    const first = await post();
    expect(first.status).toBe(201);
    expect((await post()).body.error.code).toBe('REWARD_LIMIT_REACHED');
    await ctx.tx(() => sql.exec(`UPDATE redemptions SET status='REJECTED' WHERE id=$1`, [first.body.data.redemption.id]));
    await post().expect(201);
  });

  it('rejects malformed input and staff accounts', async () => {
    expect((await ctx.api.post(path).send(body())).status).toBe(401);
    for (const patch of [{ idempotencyKey: 'bad' }, { pickupBranchId: undefined }, { marksCost: 1 }, { quantity: 2 }, { memberId }]) {
      expect((await post(body(patch))).status).toBe(400);
    }
    for (const role of ['ADMIN', 'COACH', 'RECEPTIONIST'] as const) {
      const staff = await createStaff({ role, fullName: role, phone: nextPhone() });
      const session = await login(ctx.api, staff.phone);
      expect((await post(body(), session.token)).status).toBe(403);
    }
  });

  it('does not accept rewards or branches belonging to another tenant', async () => {
    const tenant = randomUUID();
    await ownerQuery(`INSERT INTO tenants (id,code,name) VALUES ($1,$2,'Foreign redemption')`, [tenant, tenant]);
    const [branch] = await ownerQuery<{ id: string }>(`INSERT INTO branches (tenant_id,code,name) VALUES ($1,'OTHER','Foreign branch') RETURNING id`, [tenant]);
    const [reward] = await ownerQuery<{ id: string }>(`INSERT INTO rewards (tenant_id,sku,name,marks_cost,stock) VALUES ($1,'OTHER','Foreign gift',1,10) RETURNING id`, [tenant]);
    expect((await post(body({ pickupBranchId: branch.id }))).body.error.code).toBe('INVALID_PICKUP_BRANCH');
    expect((await post(body({ rewardId: reward.id }))).status).toBe(404);
    expect(await stock()).toBe(3);
  });

  it('rolls back the order, hold, inventory and stock if audit fails', async () => {
    const spy = vi.spyOn(ctx.services.audit, 'record').mockRejectedValueOnce(new Error('Audit unavailable'));
    try { expect((await post()).status).toBe(500); } finally { spy.mockRestore(); }
    expect(await stock()).toBe(3);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM redemptions WHERE member_id=$1', [memberId]))).toBe(0);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT count(*)::int FROM inventory_movements WHERE reward_id=$1', [rewardId]))).toBe(0);
    expect(await ctx.tx(() => sql.scalar<number>('SELECT marks_balance FROM members WHERE user_id=$1', [memberId]))).toBe(300);
  });
});
