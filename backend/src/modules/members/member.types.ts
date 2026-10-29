export type MemberStatus = 'ACTIVE' | 'FROZEN' | 'INACTIVE';
export type StatusChannel = 'MANUAL' | 'BATCH' | 'RENEWAL';

export interface MemberProfile {
  userId: string;
  memberCode: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  avatarUrl: string | null;
  dateOfBirth: string | null;
  gender: string | null;
  homeBranchId: string | null;
  homeBranchName: string | null;
  joinedAt: Date;
  status: MemberStatus;
  statusReason: string | null;
  statusChangedBy: string | null;
  statusChangedVia: StatusChannel | null;
  statusSince: Date | null;
  currentRankId: string | null;
  peakRankId: string | null;
  dpBalance: number;
  marksBalance: number;
  currentStreakWeeks: number;
  longestStreakWeeks: number;
  lastActivityAt: Date | null;
  duplicateOfMemberId: string | null;
}

export interface MemberSummary {
  userId: string;
  memberCode: string;
  fullName: string;
  phone: string | null;
  email: string | null;
  avatarUrl: string | null;
  status: MemberStatus;
  currentRankId: string | null;
  rankOrder: number | null;
  rankName: string | null;
  dpBalance: number;
  marksBalance: number;
  homeBranchId: string | null;
  lastActivityAt: Date | null;
  currentStreakWeeks: number;
  packageName: string | null;
  packageEndDate: string | null;
}

/** Body of PATCH /me/profile after validation: `undefined` = keep, `null` = clear. */
export interface ProfilePatch {
  fullName?: string;
  avatarUrl?: string | null;
  email?: string | null;
  phone?: string | null;
  dateOfBirth?: string | null;
  gender?: string | null;
  homeBranchId?: string | null;
}
