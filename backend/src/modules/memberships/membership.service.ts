import { AppError, badRequest, conflict, forbidden, notFound, unprocessable } from '../../common/errors/app-error';
import { DomainEvents, eventBus } from '../../common/events/event-bus';
import { clock } from '../../common/utils/clock';
import { addDays, localDate } from '../../common/utils/time';
import { env } from '../../config/env';
import type { MembershipEvent } from '../../shared/events';
import type { MembershipPort, UsableMembership } from '../../shared/ports';
import { RoleGroup } from '../../shared/roles';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { MemberService } from '../members/member.service';
import type { NotifierPort } from '../notifications/notification.service';
import type { PointsPort } from '../points/points.service';
import type { SettingsService } from '../settings/settings.service';
import type {
  MembershipRepository,
  MembershipRow,
  PackageTypeRow,
  RenewalFilter,
  RenewalRow,
} from './membership.repository';
import { isEndingSoon, isUsableOn, isValid, renewNoticeOf, usageOf } from './membership.rules';

/** Package catalogue, memberships and renewal requests. */
export class MembershipService implements MembershipPort {
  constructor(
    private readonly repo: MembershipRepository,
    private readonly settings: SettingsService,
    private readonly notifier: NotifierPort,
    private readonly audit: AuditService,
    private readonly members: MemberService,
    private readonly points: PointsPort,
  ) {}

  async listPackageTypes(includeInactive: boolean) {
    const rows = await this.repo.listPackageTypes(includeInactive);
    return rows.map(toPackageTypeView(includeInactive));
  }

  /** Member status + current package, queued package, pending renewal and the card notice (MEM-02). */
  async getMembershipOverview(memberId: string, withEvidence = false) {
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
      current: active && usage ? { ...toMembershipView(active, withEvidence), ...usage, endingSoon } : null,
      scheduled: scheduled ? toMembershipView(scheduled, withEvidence) : null,
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

  /** Reception activates a package after collecting payment (MEM-04). */
  async activateManually(
    memberId: string,
    by: string,
    actorRoles: readonly string[],
    input: { packageTypeId: string; paymentEvidenceUrl?: string; branchId?: string; note?: string },
  ) {
    return this.activatePackage({ memberId, by, actorRoles, ...input });
  }

  /** Reception approves a renewal request with the payment proof (MEM-04). */
  async approveRenewal(
    id: string,
    by: string,
    actorRoles: readonly string[],
    input: { paymentEvidenceUrl?: string; packageTypeId?: string; note?: string },
  ) {
    const evidence = checkEvidence(input.paymentEvidenceUrl);
    const rr = await this.repo.lockRenewal(id);
    if (!rr) throw notFound('Yêu cầu gia hạn');
    if (rr.status !== 'PENDING')
      throw conflict('Yêu cầu này đã được xử lý.', 'RENEWAL_ALREADY_HANDLED');
    const packageTypeId = input.packageTypeId ?? rr.desiredPackageTypeId;
    if (!packageTypeId) throw badRequest('Vui lòng chọn gói tập.', undefined, 'PACKAGE_REQUIRED');

    const result = await this.activatePackage({
      memberId: rr.memberId,
      by,
      actorRoles,
      packageTypeId,
      paymentEvidenceUrl: evidence,
      note: input.note,
    });
    await this.repo.completeRenewal({
      id,
      by,
      now: clock.now(),
      evidenceUrl: evidence,
      membershipId: result.membership.id,
      note: input.note?.trim() || null,
    });
    await this.audit.record({
      actorId: by,
      action: 'RENEWAL_COMPLETED',
      entityType: 'RENEWAL_REQUEST',
      entityId: id,
      before: { status: 'PENDING' },
      after: { status: 'COMPLETED', resultingMembershipId: result.membership.id, mode: result.mode },
      reason: 'Lễ tân duyệt yêu cầu gia hạn',
    });
    return result;
  }

  /** Shared by both endpoints. The caller's transaction plus the member row lock serialise concurrent activations. */
  private async activatePackage(input: {
    memberId: string;
    by: string;
    actorRoles: readonly string[];
    packageTypeId: string;
    paymentEvidenceUrl?: string;
    branchId?: string;
    note?: string;
  }) {
    const evidence = checkEvidence(input.paymentEvidenceUrl);
    const member = await this.repo.lockMember(input.memberId);
    if (!member) throw notFound('Học viên');
    const pkg = await this.repo.findPackageForSale(input.packageTypeId);
    if (!pkg) throw notFound('Gói tập');
    if (!pkg.isActive) throw unprocessable('Gói tập này đã ngừng bán.', 'PACKAGE_INACTIVE');
    if (input.branchId && !(await this.repo.branchExists(input.branchId))) throw notFound('Chi nhánh');
    if (await this.repo.findByStatus(input.memberId, 'SCHEDULED'))
      throw conflict(
        'Học viên đã có gói nối tiếp đang chờ kích hoạt.',
        'MEMBERSHIP_ALREADY_SCHEDULED',
      );

    const now = clock.now();
    const today = localDate(now);
    const current = await this.repo.findByStatus(input.memberId, 'ACTIVE');
    const valid = !!current && isValid(usageOf(current, today));

    let mode: 'ACTIVATED' | 'SCHEDULED' = 'ACTIVATED';
    let startDate = today;
    if (valid) {
      mode = 'SCHEDULED';
      // An open-ended current package has no end to chain after: queue the new one from today.
      if (current!.endDate) startDate = addDays(current!.endDate, 1);
    } else if (current) {
      await this.repo.expireMembership(current.id, now);
      await this.audit.record({
        actorId: input.by,
        action: 'MEMBERSHIP_EXPIRED',
        entityType: 'MEMBERSHIP',
        entityId: current.id,
        before: { status: 'ACTIVE' },
        after: { status: 'EXPIRED' },
        reason: 'Gói cũ hết hiệu lực, được thay bằng gói mới',
      });
      await eventBus.emit(DomainEvents.MEMBERSHIP_EXPIRED, {
        membershipId: current.id,
        memberId: input.memberId,
        packageTypeId: current.packageTypeId,
      } satisfies MembershipEvent);
    }

    const reactivated = mode === 'ACTIVATED' && member.status !== 'ACTIVE';
    if (reactivated)
      await this.members.changeStatus({
        memberId: input.memberId,
        status: 'ACTIVE',
        reason: 'Gia hạn gói tập',
        by: input.by,
        via: 'RENEWAL',
        actorRoles: input.actorRoles,
        notifyMember: false,
      });

    const endDate = pkg.durationDays === null ? null : addDays(startDate, pkg.durationDays - 1);
    const id = await this.repo.insertMembership({
      memberId: input.memberId,
      packageTypeId: pkg.id,
      branchId: input.branchId ?? member.homeBranchId,
      status: mode === 'ACTIVATED' ? 'ACTIVE' : 'SCHEDULED',
      startDate,
      endDate,
      totalSessions: pkg.totalSessions,
      pricePaidVnd: pkg.priceVnd,
      paymentEvidenceUrl: evidence,
      previousMembershipId: await this.repo.latestMembershipId(input.memberId),
      activatedBy: input.by,
      now,
      note: input.note?.trim() || null,
    });
    const membership = (await this.repo.findMembership(id))!;

    // MEM-05: early renewal earns Marks once per new package (the key is the new membership id).
    let bonusMarks = 0;
    if (mode === 'SCHEDULED') {
      const marks = await this.settings.getNumber('points.early_renewal_marks');
      if (marks > 0) {
        await this.points.award({
          memberId: input.memberId,
          source: 'EARLY_RENEWAL',
          marks,
          note: `Gia hạn sớm ${pkg.name}`,
          by: input.by,
          membershipId: id,
          idempotencyKey: `renewal:${id}`,
        });
        bonusMarks = marks;
      }
    }

    const message =
      mode === 'SCHEDULED'
        ? `Gia hạn sớm: gói mới xếp nối tiếp từ ${formatDmy(startDate)}` +
          (bonusMarks > 0 ? `, học viên nhận +${bonusMarks} Marks (1 lần cho mỗi gói).` : '.')
        : `Gói ${pkg.name} đã kích hoạt từ hôm nay${reactivated ? ' — tài khoản được mở lại.' : '.'}`;
    await this.audit.record({
      actorId: input.by,
      action: 'MEMBERSHIP_CREATED',
      entityType: 'MEMBERSHIP',
      entityId: id,
      after: { status: membership.status, startDate, endDate, paymentEvidenceUrl: evidence },
      reason: 'Có ảnh minh chứng thu phí',
    });
    await this.notifier.notifyMember({
      userId: input.memberId,
      event: NotificationEvent.RENEWAL_COMPLETED,
      title: 'GIA HẠN THÀNH CÔNG',
      body: message,
      payload: { membershipId: id },
      dedupeKey: `renewal-completed:${id}`,
    });
    await eventBus.emit(mode === 'SCHEDULED' ? DomainEvents.MEMBERSHIP_SCHEDULED : DomainEvents.MEMBERSHIP_ACTIVATED, {
      membershipId: id,
      memberId: input.memberId,
      packageTypeId: pkg.id,
    } satisfies MembershipEvent);
    return { membership: toMembershipView(membership, true), mode, reactivated, bonusMarks, message };
  }

  /** Reception cancels a PENDING renewal request (MEM-06). */
  async cancelRenewal(id: string, by: string, reason: string | undefined) {
    const why = requireReason(reason);
    const rr = await this.repo.lockRenewal(id);
    if (!rr) throw notFound('Yêu cầu gia hạn');
    if (rr.status !== 'PENDING') throw conflict('Yêu cầu này đã được xử lý.', 'RENEWAL_ALREADY_HANDLED');
    await this.repo.cancelRenewal({ id, by, now: clock.now(), reason: why });
    await this.audit.record({
      actorId: by,
      action: 'RENEWAL_CANCELLED',
      entityType: 'RENEWAL_REQUEST',
      entityId: id,
      before: { status: 'PENDING' },
      after: { status: 'CANCELLED' },
      reason: why,
    });
    await this.notifier.notifyMember({
      userId: rr.memberId,
      event: NotificationEvent.RENEWAL_CANCELLED,
      title: 'YÊU CẦU GIA HẠN BỊ HUỶ',
      body: `Yêu cầu gia hạn đã bị huỷ. Lý do: ${why}.`,
      payload: { renewalRequestId: id },
    });
    return toRenewalView((await this.repo.findRenewal(id))!);
  }

  /** Cancels a SCHEDULED package (reception) or the ACTIVE one (admins only) and takes back its early-renewal bonus (MEM-06). */
  async cancelMembership(id: string, by: string, actorRoles: readonly string[], reason: string | undefined) {
    const why = requireReason(reason);
    const ms = await this.repo.lockMembership(id);
    if (!ms) throw notFound('Gói tập');
    if (ms.status !== 'ACTIVE' && ms.status !== 'SCHEDULED')
      throw conflict(
        'Chỉ huỷ được gói đang hoạt động hoặc đang chờ kích hoạt.',
        'MEMBERSHIP_NOT_CANCELLABLE',
      );
    if (ms.status === 'ACTIVE') {
      if (!actorRoles.some((r) => (RoleGroup.ADMINS as readonly string[]).includes(r)))
        throw forbidden('Chỉ Admin được huỷ gói đang hoạt động.', 'ADMIN_ONLY');
      if (await this.repo.findByStatus(ms.memberId, 'SCHEDULED'))
        throw conflict('Huỷ gói nối tiếp trước.', 'CANCEL_SCHEDULED_FIRST');
    }

    try {
      await this.points.reverseByKey(`renewal:${id}`, `Huỷ gói: ${why}`, by);
    } catch (e) {
      if (e instanceof AppError && e.code === 'NEGATIVE_BALANCE')
        throw unprocessable(
          'Học viên đã dùng Marks thưởng gia hạn sớm, không thể huỷ tự động — liên hệ Admin điều chỉnh điểm.',
          'BONUS_ALREADY_SPENT',
        );
      throw e;
    }
    await this.repo.cancelMembership({ id, by, now: clock.now(), reason: why });
    // No package left: freeze the account (INACTIVE already outranks FROZEN, leave it).
    if (ms.status === 'ACTIVE' && (await this.repo.memberStatus(ms.memberId)) === 'ACTIVE')
      await this.members.changeStatus({
        memberId: ms.memberId,
        status: 'FROZEN',
        reason: `Huỷ gói tập: ${why}`,
        by,
        via: 'MANUAL',
        actorRoles,
        notifyMember: false,
      });
    await this.audit.record({
      actorId: by,
      action: 'MEMBERSHIP_CANCELLED',
      entityType: 'MEMBERSHIP',
      entityId: id,
      before: { status: ms.status },
      after: { status: 'CANCELLED' },
      reason: why,
    });
    await this.notifier.notifyMember({
      userId: ms.memberId,
      event: NotificationEvent.MEMBERSHIP_STATUS,
      title: 'GÓI TẬP ĐÃ BỊ HUỶ',
      body: `Gói ${ms.packageName} đã bị huỷ. Lý do: ${why}.`,
      payload: { membershipId: id },
    });
    const view = (await this.repo.findMembership(id))!;
    await eventBus.emit(DomainEvents.MEMBERSHIP_CANCELLED, {
      membershipId: id,
      memberId: ms.memberId,
      packageTypeId: view.packageTypeId,
    } satisfies MembershipEvent);
    return { membership: toMembershipView(view, true) };
  }

  /** MembershipPort: the ACTIVE package that can be charged for a session on `onDate` (member status is the caller's concern). */
  async findUsable(memberId: string, onDate: string): Promise<UsableMembership | null> {
    const m = await this.repo.findByStatus(memberId, 'ACTIVE');
    if (!m || !isUsableOn(m, onDate)) return null;
    return {
      id: m.id,
      packageTypeId: m.packageTypeId,
      packageName: m.packageName,
      startDate: m.startDate,
      endDate: m.endDate,
      sessionsRemaining: usageOf(m, onDate).sessionsRemaining,
      totalSessions: m.totalSessions,
      isTrial: m.isTrial,
    };
  }

  /** MembershipPort: charges one session; completes the package when the last one is used. */
  async consumeSession(membershipId: string): Promise<void> {
    const m = await this.repo.lockForConsume(membershipId);
    if (!m || m.status !== 'ACTIVE' || (m.totalSessions !== null && m.usedSessions >= m.totalSessions))
      throw unprocessable(
        'Gói tập của bạn đã hết hạn hoặc hết số buổi. Vui lòng gia hạn để tiếp tục.',
        'MEMBERSHIP_NOT_USABLE',
      );
    const complete = m.totalSessions !== null && m.usedSessions + 1 >= m.totalSessions && m.expireOnZero;
    await this.repo.addUsedSession(membershipId, complete, clock.now());
    if (complete)
      await eventBus.emit(DomainEvents.MEMBERSHIP_COMPLETED, {
        membershipId,
        memberId: m.memberId,
        packageTypeId: m.packageTypeId,
      } satisfies MembershipEvent);
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

/** Payment proof must be a file this system stored (POST /uploads?purpose=evidence). */
function checkEvidence(url: string | undefined): string {
  if (!url?.trim()) throw badRequest('Vui lòng tải ảnh minh chứng đã thu phí.', undefined, 'PAYMENT_EVIDENCE_REQUIRED');
  if (!url.startsWith(`${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/`))
    throw badRequest('Ảnh minh chứng không hợp lệ.', undefined, 'INVALID_PAYMENT_EVIDENCE');
  return url;
}

function requireReason(reason: string | undefined): string {
  if (!reason?.trim()) throw badRequest('Vui lòng nhập lý do huỷ.', undefined, 'CANCEL_REASON_REQUIRED');
  return reason.trim();
}

const formatDmy = (d: string) => d.split('-').reverse().join('/');

const toMembershipView = (m: MembershipRow, withEvidence = false) => ({
  id: m.id,
  packageType: { id: m.packageTypeId, code: m.packageCode, name: m.packageName, isTrial: m.isTrial },
  status: m.status,
  startDate: m.startDate,
  endDate: m.endDate,
  totalSessions: m.totalSessions,
  usedSessions: m.usedSessions,
  ...(withEvidence ? { paymentEvidenceUrl: m.paymentEvidenceUrl } : {}),
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
