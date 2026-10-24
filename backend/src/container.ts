import { Router } from 'express';
import { AuditService } from './modules/audit/audit.service';
import { auditRoutes } from './modules/audit/audit.routes';
import { AuthController } from './modules/auth/auth.controller';
import { AuthRepository } from './modules/auth/auth.repository';
import { authRoutes } from './modules/auth/auth.routes';
import { AuthService } from './modules/auth/auth.service';
import { createOtpSender } from './modules/auth/otp.sender';
import type { OtpSender } from './modules/auth/otp.sender';
import { MemberRepository } from './modules/members/member.repository';
import { memberRoutes } from './modules/members/member.routes';
import { MemberService } from './modules/members/member.service';
import { UserDirectory } from './modules/members/user-directory';
import { notificationRoutes } from './modules/notifications/notification.routes';
import { NotificationRepository } from './modules/notifications/notification.repository';
import { NotificationService } from './modules/notifications/notification.service';
import { createPushProvider } from './modules/notifications/push.provider';
import type { PushProvider } from './modules/notifications/push.provider';
import { PointsRepository } from './modules/points/points.repository';
import { pointsRoutes } from './modules/points/points.routes';
import { PointsService } from './modules/points/points.service';
import type { PointsAwardedEvent } from './modules/points/points.service';
import { RankRepository } from './modules/ranks/rank.repository';
import { rankRoutes } from './modules/ranks/rank.routes';
import { RankService } from './modules/ranks/rank.service';
import { settingsRoutes } from './modules/settings/settings.routes';
import { SettingsService } from './modules/settings/settings.service';
import { LocalDiskStorage } from './modules/uploads/storage.service';
import type { StorageService } from './modules/uploads/storage.service';
import { uploadRoutes } from './modules/uploads/upload.routes';
import { DomainEvents, eventBus } from './common/events/event-bus';
import { MembershipRepository } from './modules/memberships/membership.repository';
import { membershipRoutes } from './modules/memberships/membership.routes';
import { MembershipService } from './modules/memberships/membership.service';
// [imports:feature-modules] (one line per module, keep alphabetical)

/** Everything the HTTP layer and the scheduled jobs need, wired once at startup. */
export interface Container {
  services: {
    audit: AuditService;
    settings: SettingsService;
    notifications: NotificationService;
    points: PointsService;
    ranks: RankService;
    members: MemberService;
    auth: AuthService;
    directory: UserDirectory;
    memberships: MembershipService;
    // [services:feature-modules] (declare as `name: Type;` and assign in the module block below)
  };
  storage: StorageService;
  /** Routers mounted under /api/v1 (every router declares its own full paths). */
  routers: Router[];
}

export interface ContainerOverrides {
  push?: PushProvider;
  otp?: OtpSender;
  storage?: StorageService;
}

/**
 * Composition root: the ONLY place where concrete classes are instantiated and
 * wired together (dependency inversion). Feature modules depend on the narrow
 * ports they need, never on each other's repositories.
 *
 * To add a module: create its repository/service/routes, instantiate them in
 * the matching section below and push its router into `routers`.
 */
export function buildContainer(overrides: ContainerOverrides = {}): Container {
  eventBus.clear();

  // ---- 1. platform ----
  const audit = new AuditService();
  const settings = new SettingsService();
  const storage = overrides.storage ?? new LocalDiskStorage();
  const notifications = new NotificationService(new NotificationRepository(), overrides.push ?? createPushProvider(), audit);

  // ---- 2. gamification core (ledger -> ranks) ----
  const points = new PointsService(new PointsRepository(), settings, audit);
  const ranks = new RankService(new RankRepository(), points, notifications, audit, settings);
  // Any DP change re-checks the rank (promotion, demotion, restoration) in the same transaction.
  eventBus.on<PointsAwardedEvent>(DomainEvents.POINTS_AWARDED, async (e) => {
    if (e.dpDelta !== 0) await ranks.reevaluate(e.memberId);
  });

  // ---- 3. identity ----
  const members = new MemberService(new MemberRepository(), ranks, points, notifications, audit, settings);
  const auth = new AuthService(new AuthRepository(), members, overrides.otp ?? createOtpSender(), settings);
  const directory = new UserDirectory();

  const services = { audit, settings, notifications, points, ranks, members, auth, directory } as Container['services'];

  // ---- 4. feature modules ----
  // Each module registers itself here by adding ONE block: instantiate its repositories/services,
  // register event listeners, and push its router. Never reach into another module's repository;
  // depend on its exported port or listen to its domain events (src/shared/events.ts).
  const memberships = new MembershipService(new MembershipRepository(), settings, notifications, audit);
  services.memberships = memberships;
  // [modules:feature-modules]

  // ---- routers ----
  const routers: Router[] = [
    // Auth routes live under /auth, everything else declares absolute paths.
    Router().use('/auth', authRoutes(new AuthController(auth))),
    memberRoutes(members),
    rankRoutes(ranks, directory),
    pointsRoutes(points),
    notificationRoutes(notifications),
    settingsRoutes(settings),
    auditRoutes(),
    uploadRoutes(storage),
    membershipRoutes(memberships),
    // [routers:feature-modules]
  ];

  return { services, storage, routers };
}
