import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ChallengeService } from '../../src/modules/challenges/challenge.service';
import { createChallengeBody, updateChallengeBody } from '../../src/modules/challenges/challenge.validation';
import type { ChallengeRepository, ChallengeView } from '../../src/modules/challenges/challenge.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';

const valid = {
  code: 'TRAIN_OCT', title: 'Tay đấm bền bỉ', description: 'Điều kiện do Coach xác nhận',
  challengeType: 'MONTHLY', context: 'SESSION', target: 3, rewardDp: 100, rewardMarks: 40,
  startsAt: '2026-10-01T00:00:00+07:00', endsAt: '2026-11-01T00:00:00+07:00',
};

describe('Challenge validation', () => {
  it('normalizes a code and supplies draft field defaults', () => {
    const result = createChallengeBody.parse({ title: ' Test ', code: ' test_oct ', challengeType: 'WEEKLY', startsAt: valid.startsAt, endsAt: valid.endsAt });
    expect(result).toMatchObject({ title: 'Test', code: 'TEST_OCT', context: 'SESSION', target: 1, rewardDp: 0, rewardMarks: 0, description: null });
  });

  it.each([
    { target: 0 }, { target: 1.5 }, { rewardDp: -1 }, { rewardMarks: 2_147_483_648 },
    { challengeType: 'YEARLY' }, { context: 'CUSTOM' }, { startsAt: 'not-a-date' },
    { startsAt: '2026-10-01T00:00:00' }, { status: 'OPEN' }, { tenantId: 'other' },
    { title: ' ' }, { code: 'invalid code' },
  ])('rejects invalid create payload %j', (patch) => {
    expect(createChallengeBody.safeParse({ ...valid, ...patch }).success).toBe(false);
  });

  it('requires a patch field and reason, and forbids status changes', () => {
    expect(updateChallengeBody.safeParse({ reason: 'Test reason' }).success).toBe(false);
    expect(updateChallengeBody.safeParse({ title: 'New title' }).success).toBe(false);
    expect(updateChallengeBody.safeParse({ title: 'New title', status: 'OPEN', reason: 'Test reason' }).success).toBe(false);
    expect(updateChallengeBody.safeParse({ description: null, reason: 'Clear description' }).success).toBe(true);
  });
});

describe('Challenge creation and editing', () => {
  const repo = { find: vi.fn(), codeExists: vi.fn(), hasParticipants: vi.fn(), create: vi.fn(), update: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new ChallengeService(repo as unknown as ChallengeRepository, audit as unknown as AuditService);
  let row: ChallengeView;

  beforeEach(() => {
    vi.resetAllMocks();
    row = { ...createChallengeBody.parse(valid), id: 'challenge-id', startsAt: new Date(valid.startsAt), endsAt: new Date(valid.endsAt), status: 'DRAFT', createdBy: 'actor-id', createdAt: new Date('2026-09-01'), updatedAt: new Date('2026-09-01') };
    repo.find.mockResolvedValue(row);
    repo.codeExists.mockResolvedValue(false);
    repo.hasParticipants.mockResolvedValue(false);
    repo.create.mockResolvedValue(row);
    repo.update.mockImplementation(async (_id, data) => ({ ...row, ...data }));
  });

  it('creates using server actor and records audit', async () => {
    const result = await service.create(createChallengeBody.parse(valid), 'actor-id');
    expect(result.status).toBe('DRAFT');
    expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ startsAt: new Date(valid.startsAt) }), 'actor-id');
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ actorId: 'actor-id', action: 'CHALLENGE_CREATED', entityId: row.id }));
  });

  it('rejects equal/reversed dates before any insert', async () => {
    await expect(service.create(createChallengeBody.parse({ ...valid, endsAt: valid.startsAt }), 'actor-id')).rejects.toMatchObject({ code: 'INVALID_CHALLENGE_DATES' });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('rejects duplicate codes on create/update', async () => {
    repo.codeExists.mockResolvedValue(true);
    await expect(service.create(createChallengeBody.parse(valid), 'actor-id')).rejects.toMatchObject({ code: 'CHALLENGE_CODE_TAKEN' });
    await expect(service.update(row.id, { code: 'DUPLICATE', reason: 'Duplicate test' }, 'actor-id')).rejects.toMatchObject({ code: 'CHALLENGE_CODE_TAKEN' });
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('validates the merged date interval on partial update', async () => {
    await expect(service.update(row.id, { startsAt: valid.endsAt, reason: 'Change start' }, 'actor-id')).rejects.toMatchObject({ code: 'INVALID_CHALLENGE_DATES' });
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('keeps zero rewards and nullable values when editing, with before/after audit', async () => {
    const result = await service.update(row.id, { rewardDp: 0, description: null, reason: 'Update draft' }, 'actor-id');
    expect(result.rewardDp).toBe(0);
    expect(result.description).toBeNull();
    expect(repo.find).toHaveBeenCalledWith(row.id, true);
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'CHALLENGE_UPDATED', before: row, reason: 'Update draft' }));
  });

  it('locks rules once participants exist but allows title changes', async () => {
    repo.hasParticipants.mockResolvedValue(true);
    await expect(service.update(row.id, { target: 4, reason: 'Change target' }, 'actor-id')).rejects.toMatchObject({ code: 'CHALLENGE_RULES_LOCKED' });
    const result = await service.update(row.id, { title: 'New title', reason: 'Fix title' }, 'actor-id');
    expect(result.title).toBe('New title');
  });

  it('does not emit another audit for equivalent dates or unchanged values', async () => {
    await service.update(row.id, { startsAt: row.startsAt.toISOString(), title: row.title, reason: 'No change' }, 'actor-id');
    expect(repo.update).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects unknown or cancelled challenges', async () => {
    repo.find.mockResolvedValueOnce(null);
    await expect(service.update(row.id, { title: 'New title', reason: 'Edit missing' }, 'actor-id')).rejects.toMatchObject({ status: 404 });
    repo.find.mockResolvedValueOnce({ ...row, status: 'CANCELLED' });
    await expect(service.update(row.id, { title: 'New title', reason: 'Edit cancelled' }, 'actor-id')).rejects.toMatchObject({ code: 'CHALLENGE_CANCELLED' });
  });
});
