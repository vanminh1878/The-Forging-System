import { conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { localDate } from '../../common/utils/time';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { SettingsService } from '../settings/settings.service';
import type {
  MembershipRepository,
  MembershipRow,
  PackageTypeRow,
  RenewalFilter,
  RenewalRow,
} from './membership.repository';
import { isEndingSoon, isValid, renewNoticeOf, usageOf } from './membership.rules';

/** Package catalogue, memberships and renewal requests. */
export class MembershipService {
  constructor(
    private readonly repo: MembershipRepository,
    private readonly settings: SettingsService,
    private readonly notifier: NotifierPort,
    private readonly audit: AuditService,
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

  /** Member asks reception to renew (MEM-03). Approval and cancellation come with MEM-04/MEM-06. */
  async requestRenewal(memberId: string, input: { packageTypeId: string; note?: string }) {
    const status = await this.repo.memberStatus(memberId);
    if (!status) throw notFound('Học viên');
    if (status === 'INACTIVE')
      throw forbidden(
        'Tài khoản đang ngừng hoạt động. Vui lòng liên hệ lễ tân để kích hoạt lại.',
        'ACCOUNT_INACTIVE',
      );
    const pkg = await this.repo.findPackageType(input.packageTypeId);
    if (!pkg || !pkg.isActive)
      throw unprocessable('Gói tập này hiện không còn được bán.', 'PACKAGE_NOT_AVAILABLE');

    const current = await this.repo.findByStatus(memberId, 'ACTIVE');
    const id = await this.repo.insertRenewal({
      memberId,
      currentMembershipId: current?.id ?? null,
      packageTypeId: pkg.id,
      note: input.note?.trim() || null,
    });
    if (!id)
      throw conflict(
        'Bạn đã có một yêu cầu gia hạn đang chờ xử lý. Lễ tân sẽ xử lý sớm.',
        'RENEWAL_PENDING_EXISTS',
      );

    const view = (await this.repo.findRenewal(id))!;
    await this.audit.record({
      actorId: memberId,
      action: 'RENEWAL_REQUESTED',
      entityType: 'RENEWAL_REQUEST',
      entityId: id,
      after: { packageTypeId: pkg.id, currentMembershipId: current?.id ?? null, note: input.note ?? null },
      reason: 'Học viên gửi yêu cầu gia hạn',
    });
    // Rows are written inside this transaction; the notifier schedules the push after commit.
    await this.notifier.notifyMember({
      userId: memberId,
      event: NotificationEvent.RENEWAL_SENT,
      title: 'Đã gửi yêu cầu gia hạn',
      body: `Yêu cầu gia hạn gói ${pkg.name} đã được gửi. Lễ tân sẽ liên hệ với bạn sớm.`,
      payload: { renewalRequestId: id },
    });
    await this.notifier.notifyStaff(
      'RECEPTIONIST',
      NotificationEvent.RENEWAL_REQUEST,
      'Yêu cầu gia hạn mới',
      `${view.memberName} (${view.memberCode}) xin gia hạn gói ${pkg.name}.`,
    );
    return toRenewalView(view);
  }

  async listRenewals(filter: RenewalFilter, limit: number, offset: number) {
    const { items, total } = await this.repo.listRenewals(filter, limit, offset);
    return { items: items.map(toRenewalView), total };
  }
}

const toRenewalView = (r: RenewalRow) => ({
  id: r.id,
  status: r.status,
  note: r.note,
  reason: r.reason,
  createdAt: r.createdAt,
  handledAt: r.handledAt,
  member: { id: r.memberId, fullName: r.memberName, phone: r.memberPhone, memberCode: r.memberCode },
  desiredPackage: r.desiredPackageTypeId && {
    id: r.desiredPackageTypeId,
    name: r.desiredPackageName,
    priceVnd: r.desiredPriceVnd === null ? null : Number(r.desiredPriceVnd),
  },
  currentMembership: r.currentMembershipId && {
    id: r.currentMembershipId,
    packageName: r.currentPackageName,
    endDate: r.currentEndDate,
  },
});

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
