import { notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { localDate } from '../../common/utils/time';
import type { SettingsService } from '../settings/settings.service';
import type { MembershipRepository, MembershipRow, PackageTypeRow } from './membership.repository';
import { isEndingSoon, isValid, renewNoticeOf, usageOf } from './membership.rules';

/** Package catalogue, memberships and renewal requests. */
export class MembershipService {
  constructor(
    private readonly repo: MembershipRepository,
    private readonly settings: SettingsService,
  ) {}

  async listPackageTypes(includeInactive: boolean) {
    const rows = await this.repo.listPackageTypes(includeInactive);
    return rows.map(toPackageTypeView(includeInactive));
  }

  /** Member status + current package, queued package, pending renewal and the card notice (MEM-02). */
  async getMembershipOverview(memberId: string) {
    const memberStatus = await this.repo.memberStatus(memberId);
    if (!memberStatus) throw notFound('Học viên');
    const today = localDate(clock.now());
    const [active, scheduled, hasEnded, pending] = await Promise.all([
      this.repo.findByStatus(memberId, 'ACTIVE'),
      this.repo.findByStatus(memberId, 'SCHEDULED'),
      this.repo.hasEndedMembership(memberId),
      this.repo.findPendingRenewal(memberId),
    ]);
    const remindDays = await this.settings.getNumber('membership.remind_days');
    const remindSessions = await this.settings.getNumber('membership.remind_sessions');

    const usage = active ? usageOf(active, today) : null;
    const endingSoon = usage ? isEndingSoon(usage, remindDays, remindSessions) : false;
    return {
      memberStatus,
      current: active && usage ? { ...toMembershipView(active), ...usage, endingSoon } : null,
      scheduled: scheduled ? toMembershipView(scheduled) : null,
      pendingRenewal: pending && {
        id: pending.id,
        packageTypeId: pending.desiredPackageTypeId,
        packageName: pending.desiredPackageName,
        priceVnd: pending.desiredPriceVnd === null ? null : Number(pending.desiredPriceVnd),
        note: pending.note,
        createdAt: pending.createdAt,
      },
      renewNotice: renewNoticeOf({ current: usage, hasScheduled: !!scheduled, hasEnded, endingSoon }),
      canRenewEarly: !!usage && isValid(usage) && !scheduled,
    };
  }
}

const toMembershipView = (m: MembershipRow) => ({
  id: m.id,
  packageType: { id: m.packageTypeId, code: m.packageCode, name: m.packageName, isTrial: m.isTrial },
  status: m.status,
  startDate: m.startDate,
  endDate: m.endDate,
  totalSessions: m.totalSessions,
  usedSessions: m.usedSessions,
});

const toPackageTypeView = (withActive: boolean) => (r: PackageTypeRow) => ({
  id: r.id,
  code: r.code,
  name: r.name,
  durationDays: r.durationDays,
  totalSessions: r.totalSessions,
  sessionsPerWeek: r.sessionsPerWeek,
  isTrial: r.isTrial,
  priceVnd: r.priceVnd === null ? null : Number(r.priceVnd),
  description: r.description,
  ...(withActive ? { isActive: r.isActive } : {}),
});
