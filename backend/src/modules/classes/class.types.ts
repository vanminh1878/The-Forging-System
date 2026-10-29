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
