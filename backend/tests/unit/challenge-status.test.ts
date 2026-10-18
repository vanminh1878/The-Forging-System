import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { ChallengeService } from '../../src/modules/challenges/challenge.service';
import { challengeEnabledBody } from '../../src/modules/challenges/challenge.validation';
import type { ChallengeRepository, ChallengeView } from '../../src/modules/challenges/challenge.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';

describe('CHL-02 request validation', () => {
  it('requires an explicit boolean and a meaningful reason', () => {
    expect(challengeEnabledBody.parse({ enabled: false, reason: '  Tạm đóng  ' })).toEqual({ enabled: false, reason: 'Tạm đóng' });
  });

  it.each([
    {}, { enabled: true }, { reason: 'Đóng thử thách' },
    { enabled: 'false', reason: 'Đóng thử thách' }, { enabled: 1, reason: 'Mở thử thách' },
    { enabled: true, reason: '  ' }, { enabled: null, reason: 'Đóng thử thách' },
    { enabled: true, reason: 'Test', status: 'OPEN' },
  ])('rejects invalid body %j', (body) => {
    expect(challengeEnabledBody.safeParse(body).success).toBe(false);
  });
});

describe('CHL-02 activation state machine', () => {
  const repo = { find: vi.fn(), setStatus: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new ChallengeService(repo as unknown as ChallengeRepository, audit as unknown as AuditService);
  let row: ChallengeView;

  beforeEach(() => {
    vi.resetAllMocks();
    setClock(fixedClock(new Date('2026-10-15T12:00:00Z')));
    row = { id: 'challenge', code: 'TEST', title: 'Test challenge', description: null,
      challengeType: 'MONTHLY', context: 'SESSION', target: 3, rewardDp: 100, rewardMarks: 40,
      startsAt: new Date('2026-10-01T00:00:00Z'), endsAt: new Date('2026-11-01T00:00:00Z'),
      status: 'DRAFT', createdBy: 'admin', createdAt: new Date('2026-09-01'), updatedAt: new Date('2026-09-01') };
    repo.find.mockImplementation(async () => row);
    repo.setStatus.mockImplementation(async (_id, status) => ({ ...row, status }));
  });
  afterEach(resetClock);

  it.each(['DRAFT', 'CLOSED'] as const)('publishes %s with before/after audit', async (status) => {
    row.status = status;
    const result = await service.setEnabled(row.id, { enabled: true, reason: 'Publish challenge' }, 'admin');
    expect(result).toMatchObject({ status: 'OPEN', enabled: true });
    expect(repo.find).toHaveBeenCalledWith(row.id, true);
    expect(repo.setStatus).toHaveBeenCalledWith(row.id, 'OPEN');
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ actorId: 'admin', action: 'CHALLENGE_ENABLED', before: row, after: expect.objectContaining({ status: 'OPEN' }), reason: 'Publish challenge' }));
  });

  it('closes OPEN even after expiry without validating activation rules', async () => {
    row.status = 'OPEN';
    row.endsAt = new Date('2026-10-10');
    const result = await service.setEnabled(row.id, { enabled: false, reason: 'Close challenge' }, 'admin');
    expect(result).toMatchObject({ status: 'CLOSED', enabled: false });
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'CHALLENGE_DISABLED' }));
  });

  it.each(['DRAFT', 'CLOSED', 'CANCELLED'] as const)('keeps disabling %s a no-op', async (status) => {
    row.status = status;
    const result = await service.setEnabled(row.id, { enabled: false, reason: 'Repeated disable' }, 'admin');
    expect(result).toMatchObject({ status, enabled: false, updatedAt: row.updatedAt });
    expect(repo.setStatus).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('keeps enabling an unexpired OPEN challenge a no-op', async () => {
    row.status = 'OPEN';
    expect(await service.setEnabled(row.id, { enabled: true, reason: 'Already enabled' }, 'admin')).toMatchObject({ status: 'OPEN', enabled: true });
    expect(repo.setStatus).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('allows publication before startsAt', async () => {
    row.startsAt = new Date('2026-10-20');
    expect(await service.setEnabled(row.id, { enabled: true, reason: 'Publish early' }, 'admin')).toMatchObject({ status: 'OPEN', enabled: true });
  });

  it.each(['2026-10-15T12:00:00Z', '2026-10-14T12:00:00Z'])('rejects enabling at/past deadline %s', async (deadline) => {
    row.endsAt = new Date(deadline);
    await expect(service.setEnabled(row.id, { enabled: true, reason: 'Publish expired' }, 'admin')).rejects.toMatchObject({ code: 'CHALLENGE_EXPIRED', status: 409 });
    expect(repo.setStatus).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects invalid date intervals', async () => {
    row.startsAt = row.endsAt;
    await expect(service.setEnabled(row.id, { enabled: true, reason: 'Invalid dates' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_CHALLENGE_DATES' });
  });

  it.each([{ target: 0 }, { rewardDp: -1 }, { rewardMarks: -1 }])('rejects invalid legacy configuration %j', async (patch) => {
    Object.assign(row, patch);
    await expect(service.setEnabled(row.id, { enabled: true, reason: 'Invalid rules' }, 'admin')).rejects.toMatchObject({ code: 'INVALID_CHALLENGE_CONFIG' });
    expect(repo.setStatus).not.toHaveBeenCalled();
  });

  it('rejects cancelled or missing challenges without audit', async () => {
    row.status = 'CANCELLED';
    await expect(service.setEnabled(row.id, { enabled: true, reason: 'Open cancelled' }, 'admin')).rejects.toMatchObject({ code: 'CHALLENGE_CANCELLED' });
    repo.find.mockResolvedValue(null);
    await expect(service.setEnabled(row.id, { enabled: false, reason: 'Missing object' }, 'admin')).rejects.toMatchObject({ status: 404 });
    expect(audit.record).not.toHaveBeenCalled();
  });
});
