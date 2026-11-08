import { afterEach, describe, expect, it, vi } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { ChallengeRepository } from '../../src/modules/challenges/challenge.repository';
import { ChallengeService } from '../../src/modules/challenges/challenge.service';
import { env } from '../../src/config/env';
import type { AttendanceConfirmedEvent } from '../../src/shared/events';

const event: AttendanceConfirmedEvent = {
  attendanceId: 'attendance-1',
  memberId: 'member-1',
  sessionId: 'session-1',
  branchId: 'branch-1',
  sessionDate: '2026-10-15',
  completionPct: 100,
  isExam: false,
  sessionType: 'REGULAR',
  confirmedBy: 'coach-1',
  membershipId: 'membership-1',
};

const participation = {
  id: 'participation-1',
  challengeId: 'challenge-1',
  memberId: event.memberId,
  status: 'JOINED' as const,
  progressValue: 2,
  evidenceUrl: null,
  evidenceAt: null,
  joinedAt: new Date('2026-10-01'),
  completedAt: null,
  confirmedBy: null,
  confirmedAt: null,
  isLimited: false,
  rewardedAt: null,
  updatedAt: new Date('2026-10-15'),
};

describe('CHL-05 challenge progression', () => {
  const repo = { recordAttendanceProgress: vi.fn() };
  const audit = { record: vi.fn() };
  const service = new ChallengeService(
    repo as unknown as ChallengeRepository,
    audit as unknown as AuditService,
  );

  afterEach(() => {
    vi.resetAllMocks();
    resetClock();
  });

  it('maps a confirmed regular session to SESSION and records progress audit', async () => {
    setClock(fixedClock(new Date('2026-10-15T12:00:00Z')));
    repo.recordAttendanceProgress.mockResolvedValue([{ participation, target: 3 }]);

    await service.recordConfirmedAttendance(event);

    expect(repo.recordAttendanceProgress).toHaveBeenCalledWith(
      event.memberId,
      event.attendanceId,
      'SESSION',
      new Date('2026-10-15T12:00:00Z'),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CHALLENGE_PROGRESS_UPDATED',
        entityId: participation.id,
        after: expect.objectContaining({ attendanceId: event.attendanceId, target: 3 }),
      }),
    );
  });

  it('maps workshop and exam events, and records target completion awaiting coach review', async () => {
    const complete = {
      ...participation,
      status: 'AWAITING_COACH' as const,
      progressValue: 3,
      completedAt: new Date(),
    };
    repo.recordAttendanceProgress.mockResolvedValue([{ participation: complete, target: 3 }]);

    await service.recordConfirmedAttendance({ ...event, sessionType: 'WORKSHOP' });
    expect(repo.recordAttendanceProgress).toHaveBeenLastCalledWith(
      event.memberId,
      event.attendanceId,
      'WORKSHOP',
      expect.any(Date),
    );
    expect(audit.record).toHaveBeenLastCalledWith(
      expect.objectContaining({ action: 'CHALLENGE_TARGET_REACHED' }),
    );

    await service.recordConfirmedAttendance({ ...event, isExam: true, sessionType: 'WORKSHOP' });
    expect(repo.recordAttendanceProgress).toHaveBeenLastCalledWith(
      event.memberId,
      event.attendanceId,
      'EXAM',
      expect.any(Date),
    );
  });

  it('does not audit when the repository rejects an already-recorded or ineligible event', async () => {
    repo.recordAttendanceProgress.mockResolvedValue([]);
    await service.recordConfirmedAttendance(event);
    expect(audit.record).not.toHaveBeenCalled();
  });
});

describe('CHL-06 evidence and coach approval', () => {
  const repo = {
    findParticipation: vi.fn(),
    findParticipationById: vi.fn(),
    find: vi.fn(),
    submitCompletionEvidence: vi.fn(),
    approveJoin: vi.fn(),
    lockMember: vi.fn(),
    rewardedThisMonth: vi.fn(),
    approveParticipation: vi.fn(),
  };
  const audit = { record: vi.fn() };
  const points = { award: vi.fn(), reverseByKey: vi.fn() };
  const settings = { getNumber: vi.fn() };
  const notifier = { notifyMember: vi.fn(), notifyFromTemplate: vi.fn(), notifyStaff: vi.fn() };
  const service = new ChallengeService(
    repo as unknown as ChallengeRepository,
    audit as unknown as AuditService,
    points,
    settings as never,
    notifier,
  );
  const awaiting = {
    ...participation,
    status: 'AWAITING_COACH' as const,
    progressValue: 3,
    evidenceUrl: null,
    completedAt: new Date('2026-10-15'),
  };
  const challenge = {
    id: 'challenge-1',
    code: 'CHL',
    title: 'Ba buổi tập',
    description: null,
    challengeType: 'MONTHLY' as const,
    context: 'SESSION' as const,
    target: 3,
    rewardDp: 100,
    rewardMarks: 20,
    startsAt: new Date('2026-10-01'),
    endsAt: new Date('2026-11-01'),
    status: 'OPEN' as const,
    createdBy: 'admin-1',
    createdAt: new Date('2026-10-01'),
    updatedAt: new Date('2026-10-01'),
  };

  afterEach(() => {
    vi.resetAllMocks();
    resetClock();
  });

  it('allows a Coach-approved member to request completion with a stored-file proof', async () => {
    const url = `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/challenges/proof.jpg`;
    const joined = { ...awaiting, status: 'JOINED' as const };
    repo.findParticipation.mockResolvedValue(joined);
    repo.submitCompletionEvidence.mockResolvedValue({ ...awaiting, evidenceUrl: url, evidenceAt: new Date() });
    repo.find.mockResolvedValue(challenge);

    const result = await service.submitEvidence(event.memberId, awaiting.challengeId, { evidenceUrl: url });

    expect(result.evidenceUrl).toBe(url);
    expect(repo.submitCompletionEvidence).toHaveBeenCalledWith(awaiting.id, url, expect.any(Date));
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'CHALLENGE_EVIDENCE_SUBMITTED' }),
    );
    expect(notifier.notifyStaff).toHaveBeenCalledWith(
      'COACH',
      'CHALLENGE_EVIDENCE',
      'BẰNG CHỨNG CHALLENGE MỚI',
      expect.stringContaining(challenge.title),
    );
  });

  it('rejects proof before Coach approves joining and off-platform URLs', async () => {
    repo.findParticipation.mockResolvedValue({ ...awaiting, status: 'PENDING_COACH' });
    await expect(
      service.submitEvidence(event.memberId, awaiting.challengeId, {
        evidenceUrl: 'https://outside.example/proof.jpg',
      }),
    ).rejects.toMatchObject({ code: 'CHALLENGE_NOT_JOINED' });
    repo.findParticipation.mockResolvedValue({ ...awaiting, status: 'JOINED' });
    await expect(
      service.submitEvidence(event.memberId, awaiting.challengeId, {
        evidenceUrl: 'https://outside.example/proof.jpg',
      }),
    ).rejects.toMatchObject({ code: 'INVALID_CHALLENGE_EVIDENCE' });
  });

  it('lets Coach approve a pending registration before evidence can be sent', async () => {
    const pending = { ...awaiting, status: 'PENDING_COACH' as const };
    const joined = { ...awaiting, status: 'JOINED' as const };
    repo.findParticipationById.mockResolvedValue(pending);
    repo.approveJoin.mockResolvedValue(joined);
    repo.find.mockResolvedValue(challenge);

    await expect(service.approveJoin(pending.id, event.confirmedBy)).resolves.toEqual(joined);
    expect(repo.approveJoin).toHaveBeenCalledWith(pending.id, event.confirmedBy, expect.any(Date));
    expect(notifier.notifyMember).toHaveBeenCalledWith(expect.objectContaining({
      event: 'CHALLENGE_JOIN_APPROVED', userId: event.memberId,
    }));
  });

  it('approves evidence once, awards configured points, and marks repeat approval duplicate', async () => {
    const withEvidence = {
      ...awaiting,
      evidenceUrl: `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/challenges/proof.jpg`,
    };
    const rewarded = {
      ...withEvidence,
      status: 'REWARDED' as const,
      isLimited: false,
      rewardedAt: new Date(),
    };
    repo.findParticipationById.mockResolvedValueOnce(withEvidence).mockResolvedValueOnce(rewarded);
    repo.find.mockResolvedValue(challenge);
    repo.rewardedThisMonth.mockResolvedValue(0);
    settings.getNumber.mockResolvedValue(2);
    points.award.mockResolvedValue({ duplicate: false, transaction: {} });
    repo.approveParticipation.mockResolvedValue(rewarded);

    expect(await service.approveEvidence(withEvidence.id, event.confirmedBy)).toMatchObject({
      duplicate: false,
      participation: rewarded,
    });
    expect(points.award).toHaveBeenCalledWith(
      expect.objectContaining({
        source: 'CHALLENGE',
        dp: 100,
        marks: 20,
        challengeParticipationId: withEvidence.id,
        idempotencyKey: `challenge:reward:${withEvidence.id}`,
      }),
    );
    expect(repo.approveParticipation).toHaveBeenCalledWith(
      withEvidence.id,
      event.confirmedBy,
      expect.any(Date),
      false,
    );
    expect(await service.approveEvidence(withEvidence.id, event.confirmedBy)).toEqual({
      participation: rewarded,
      duplicate: true,
    });
  });

  it('confirms a limited reward without posting points', async () => {
    const withEvidence = {
      ...awaiting,
      evidenceUrl: `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/challenges/proof.jpg`,
    };
    repo.findParticipationById.mockResolvedValue(withEvidence);
    repo.find.mockResolvedValue(challenge);
    repo.rewardedThisMonth.mockResolvedValue(2);
    settings.getNumber.mockResolvedValue(2);
    repo.approveParticipation.mockResolvedValue({ ...withEvidence, status: 'REWARDED', isLimited: true });

    await service.approveEvidence(withEvidence.id, event.confirmedBy);

    expect(points.award).not.toHaveBeenCalled();
    expect(repo.approveParticipation).toHaveBeenCalledWith(
      withEvidence.id,
      event.confirmedBy,
      expect.any(Date),
      true,
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'CHALLENGE_APPROVED_LIMITED' }),
    );
  });
});
