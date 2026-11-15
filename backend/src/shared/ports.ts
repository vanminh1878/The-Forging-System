/**
 * Narrow interfaces that let a module use another module without importing its
 * implementation (dependency inversion). The owning module implements the port;
 * consumers receive it through their constructor or a lazy getter.
 */

export interface UsableMembership {
  id: string;
  packageTypeId: string;
  packageName: string;
  /** YYYY-MM-DD; null for packages without an end date. */
  startDate: string;
  endDate: string | null;
  /** Null when the package is not limited by session count. */
  sessionsRemaining: number | null;
  totalSessions: number | null;
  isTrial: boolean;
}

/** Implemented by the memberships module ("gói tập"). */
export interface MembershipPort {
  /**
   * The ACTIVE membership that would be charged for a session held on `onDate`
   * (local date, YYYY-MM-DD): started, not past its end date, sessions left.
   * Returns null when the learner has no usable membership.
   */
  findUsable(memberId: string, onDate: string): Promise<UsableMembership | null>;
  /**
   * Charges one session to the membership (row locked). Completes the package and emits
   * MEMBERSHIP_COMPLETED when the last session is used and the package type expires on zero.
   * Throws 422 MEMBERSHIP_NOT_USABLE when the membership is not ACTIVE or has no sessions left.
   */
  consumeSession(membershipId: string): Promise<void>;
}

/** What `enrollForMembership` leaves behind, echoed to the receptionist. */
export interface PackageEnrollment {
  classId: string;
  className: string;
  /** YYYY-MM-DD */
  startDate: string;
  endDate: string | null;
}

/** Implemented by the classes module; memberships uses it to pair a package with a class. */
export interface ClassPort {
  /** Does the package type have at least one ACTIVE class to choose from? */
  hasActiveClasses(packageTypeId: string): Promise<boolean>;
  /**
   * Throws 404 (no such class), 422 CLASS_NOT_IN_PACKAGE, 422 CLASS_INACTIVE or 409 CLASS_FULL.
   * With `memberId`, a member already ACTIVE in the class does not need a free seat (same-class renewal).
   */
  checkEnrollable(classId: string, packageTypeId: string, memberId?: string): Promise<void>;
  /**
   * Enrols the member in the class for the new membership's date range (row lock + capacity check).
   * An ACTIVE enrolment in the same class is extended instead of duplicated. Audits ROSTER_UPDATED (reason PACKAGE).
   */
  enrollForMembership(input: {
    classId: string;
    memberId: string;
    membershipId: string;
    startDate: string;
    endDate: string | null;
    actorId: string;
  }): Promise<PackageEnrollment>;
}
