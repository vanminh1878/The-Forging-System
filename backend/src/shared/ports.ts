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
}
