import { describe, expect, it } from 'vitest';
import { auditQuery } from '../../src/modules/audit/audit.validation';

describe('CFG-10 audit filters', () => {
  it('defaults pagination and accepts text entity IDs and timezone offsets', () => {
    const result = auditQuery.parse({ entityId: 'points.dp_monthly_cap', from: '2026-10-01T00:00:00+07:00', to: '2026-10-31T23:59:59Z' });
    expect(result).toMatchObject({ entityId: 'points.dp_monthly_cap', page: 1, limit: 20 });
  });

  it('compares instants across timezones and permits equal inclusive boundaries', () => {
    expect(auditQuery.safeParse({ from: '2026-10-01T07:00:00+07:00', to: '2026-10-01T00:00:00Z' }).success).toBe(true);
    expect(auditQuery.safeParse({ from: '2026-10-01T01:00:00Z', to: '2026-10-01T07:00:00+07:00' }).success).toBe(false);
  });

  it.each([
    { actorId: 'not-uuid' }, { actorType: 'ADMIN' }, { action: ' ' }, { entityType: '' }, { entityId: '' },
    { from: '2026-10-01' }, { to: 'invalid' }, { from: '2026-10-01T00:00:00' },
    { page: 0 }, { limit: 101 }, { unexpected: 'filter' }, { q: 'a'.repeat(101) },
  ])('rejects invalid query %j', (query) => {
    expect(auditQuery.safeParse(query).success).toBe(false);
  });

  it('supports USER and SYSTEM filters and trims literal search text', () => {
    expect(auditQuery.parse({ actorType: 'SYSTEM', q: '  100% _  ' })).toMatchObject({ actorType: 'SYSTEM', q: '100% _' });
    expect(auditQuery.safeParse({ actorType: 'USER', actorId: '00000000-0000-4000-8000-000000000001' }).success).toBe(true);
  });
});
