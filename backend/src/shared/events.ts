/**
 * Payload contracts of cross-module domain events (see common/events/event-bus.ts).
 * Modules communicate through these events instead of importing each other's services:
 * the emitter owns the payload type, listeners register in their own module factory.
 */

/** A coach (or reception) confirmed a learner's attendance of a session (>= completion threshold). */
export interface AttendanceConfirmedEvent {
  attendanceId: string;
  memberId: string;
  sessionId: string;
  branchId: string;
  /** Local calendar date (YYYY-MM-DD) of the session. */
  sessionDate: string;
  completionPct: number;
  isExam: boolean;
  /** SessionType code, e.g. REGULAR | ACADEMY | EXAM. */
  sessionType: string;
  confirmedBy: string;
  /** Membership charged for this session (set at check-in); null when none was linked. */
  membershipId: string | null;
}

/** A coach recorded the PASS/FAIL result of an Academy / exam session for a learner (attendance module). */
export interface AcademyResultRecordedEvent {
  attendanceId: string;
  memberId: string;
  sessionId: string;
  branchId: string;
  passed: boolean;
  recordedBy: string;
}

export interface MembershipEvent {
  membershipId: string;
  memberId: string;
  packageTypeId: string;
}

/** A learner finished every lesson of a course ("khóa"); the course gate of the rank engine may now be satisfied. */
export interface CourseCompletedEvent {
  memberId: string;
  courseId: string;
  courseName: string;
  enrollmentId: string;
}

/** The weekly streak close processed one learner (INCREASED / FROZEN / RESET / SKIPPED). */
export interface StreakWeekClosedEvent {
  memberId: string;
  /** Monday (local) of the closed week, YYYY-MM-DD. */
  weekStart: string;
  result: 'INCREASED' | 'FROZEN' | 'RESET' | 'SKIPPED';
  streakBefore: number;
  streakAfter: number;
}

export interface MemberStatusChangedEvent {
  memberId: string;
  from: string;
  to: string;
  reason: string;
}

export interface RedemptionCreatedEvent {
  redemptionId: string;
  memberId: string;
  rewardId: string;
  pickupBranchId: string;
}

/** A session was cancelled by staff (learners on its roster were notified). */
export interface SessionCancelledEvent {
  sessionId: string;
  classId: string | null;
  branchId: string;
  reason: string;
  cancelledBy: string;
}

/** A session moved to another time / branch / coach. Instants are ISO-8601 strings. */
export interface SessionRescheduledEvent {
  sessionId: string;
  classId: string | null;
  branchId: string;
  previousStartsAt: string;
  startsAt: string;
  rescheduledBy: string;
}
