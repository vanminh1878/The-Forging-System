import { beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('member notification inbox: paging and counts (NTF-02)', () => {
  let ctx: TestContext;
  let member: { token: string; userId: string };
  let other: { token: string; userId: string };
  let otherBranch: string;

  const list = (query: string, token = member.token) => ctx.api.get(`/api/v1/me/notifications${query}`).set(bearer(token));

  async function personal(userId: string, title: string, minutesAgo: number) {
    await ownerQuery(
      `INSERT INTO notifications (tenant_id, user_id, event_type, title, body, created_at)
       VALUES ($1, $2, 'SESSION_COMPLETED', $3, 'body', now() - ($4 || ' minutes')::interval)`,
      [ctx.tenantId, userId, title, String(minutesAgo)],
    );
  }
  async function broadcast(title: string, minutesAgo: number, branchId: string | null = null) {
    await ownerQuery(
      `INSERT INTO notifications (tenant_id, user_id, branch_id, event_type, title, body, created_at)
       VALUES ($1, NULL, $2, 'BROADCAST', $3, 'body', now() - ($4 || ' minutes')::interval)`,
      [ctx.tenantId, branchId, title, String(minutesAgo)],
    );
  }

  beforeAll(async () => {
    ctx = await bootTestApp();
    member = await registerMember(ctx.api);
    other = await registerMember(ctx.api);
    // Registration creates a WELCOME notification. This suite owns its inbox
    // fixture and verifies paging/counts for the rows created below.
    await ownerQuery(
      `DELETE FROM notifications WHERE event_type = 'WELCOME' AND user_id IN ($1, $2)`,
      [member.userId, other.userId],
    );
    // The member's own: three personal notifications and one broadcast to everyone, oldest first by minutes ago.
    await personal(member.userId, 'P1', 1);
    await personal(member.userId, 'P2', 2);
    await personal(member.userId, 'P3', 3);
    await broadcast('B-ALL', 4);
    // Not the member's: someone else's, and a broadcast aimed at a branch the member does not belong to.
    await personal(other.userId, 'OTHER', 1);
    const branches = await ownerQuery<{ id: string }>(`SELECT id FROM branches ORDER BY code`);
    otherBranch = branches[0].id;
    await ownerQuery(`UPDATE members SET home_branch_id = $2 WHERE user_id = $1`, [member.userId, branches[1].id]);
    await broadcast('B-OTHER-BRANCH', 5, otherBranch);
  });

  it('reports the true total, so the app knows when the last page is reached', async () => {
    const first = await list('?page=1&limit=3');
    expect(first.status).toBe(200);
    expect(first.body.data.map((n: { title: string }) => n.title)).toEqual(['P1', 'P2', 'P3']);
    expect(first.body.meta).toMatchObject({ page: 1, limit: 3, total: 4, totalPages: 2, unread: 4 });

    const second = await list('?page=2&limit=3');
    expect(second.body.data.map((n: { title: string }) => n.title)).toEqual(['B-ALL']);
    expect(second.body.meta).toMatchObject({ page: 2, limit: 3, total: 4, totalPages: 2 });
  });

  it('counts only what the member can see: not other people\'s, not other branches\' broadcasts', async () => {
    const all = await list('?limit=50');
    expect(all.body.meta.total).toBe(4);
    expect(all.body.data.map((n: { title: string }) => n.title)).not.toContain('OTHER');
    expect(all.body.data.map((n: { title: string }) => n.title)).not.toContain('B-OTHER-BRANCH');
    expect((await list('?limit=50', other.token)).body.meta.total).toBe(2); // OTHER and the broadcast to everyone
  });

  it('keeps the total when notifications are read, and gives the counts as numbers', async () => {
    const id = (await list('?limit=50')).body.data[0].id as string;
    expect((await ctx.api.post(`/api/v1/me/notifications/${id}/read`).set(bearer(member.token))).status).toBe(204);
    const after = await list('?limit=50');
    expect(after.body.meta.total).toBe(4);
    expect(after.body.meta.unread).toBe(3);
    expect(typeof after.body.meta.unread).toBe('number');
    const count = await ctx.api.get('/api/v1/me/notifications/unread-count').set(bearer(member.token));
    expect(count.body.data.unread).toBe(3);
  });

  it('answers a page past the end with no rows and the same total', async () => {
    const past = await list('?page=5&limit=3');
    expect(past.body.data).toEqual([]);
    expect(past.body.meta).toMatchObject({ page: 5, total: 4, totalPages: 2 });
  });
});
