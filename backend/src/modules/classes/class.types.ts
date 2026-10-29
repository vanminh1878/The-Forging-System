export interface ClassRow {
  id: string;
  branchId: string;
  name: string;
  sessionTypeCode: string;
  courseId: string | null;
  defaultCoachId: string | null;
  weekdays: number[];
  /** HH:mm */
  startTime: string;
  durationMinutes: number;
  capacity: number | null;
  isActive: boolean;
}

export interface RosterEntry {
  enrollmentId: string;
  memberId: string;
  memberCode: string;
  fullName: string;
  membershipId: string | null;
  startDate: string;
  endDate: string | null;
}

export interface ClassInput {
  branchId: string;
  name: string;
  sessionTypeCode: string;
  courseId: string | null;
  defaultCoachId: string | null;
  weekdays: number[];
  startTime: string;
  durationMinutes: number;
  capacity: number | null;
  isActive: boolean;
}

export interface SessionRow {
  id: string;
  classId: string | null;
  title: string | null;
  startsAt: Date;
  endsAt: Date;
  /** Local (tenant timezone) calendar date, YYYY-MM-DD. */
  date: string;
  status: string;
  isExam: boolean;
  capacity: number | null;
  coach: { id: string; fullName: string };
  attendeeCount: number;
}

export interface SessionTypeRow {
  code: string;
  maxDp: number;
  maxDpUpper: number | null;
}

export interface SessionInput {
  classId: string | null;
  branchId: string;
  sessionTypeCode: string;
  coachId: string;
  lessonPlanId: string | null;
  title: string | null;
  startsAt: Date;
  endsAt: Date;
  maxDpOverride: number | null;
  isExam: boolean;
  capacity: number | null;
  notes: string | null;
  createdBy: string;
}

export interface SessionRecord extends Omit<SessionInput, 'createdBy'> {
  id: string;
  status: string;
}
