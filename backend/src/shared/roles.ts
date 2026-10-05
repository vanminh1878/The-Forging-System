/** Role codes stored in `roles.code` / `user_roles.role_code`. */
export const Role = {
  MEMBER: 'MEMBER',
  COACH: 'COACH',
  HEAD_COACH: 'HEAD_COACH',
  RECEPTIONIST: 'RECEPTIONIST',
  ADMIN: 'ADMIN',
  SUPER_ADMIN: 'SUPER_ADMIN',
} as const;

export type RoleCode = (typeof Role)[keyof typeof Role];

/** Role groups used by route guards. */
export const RoleGroup = {
  COACHES: [Role.COACH, Role.HEAD_COACH],
  /** Coaches plus admins: anyone allowed to confirm sessions and review evidence. */
  COACHING_STAFF: [Role.COACH, Role.HEAD_COACH, Role.ADMIN, Role.SUPER_ADMIN],
  RECEPTION: [Role.RECEPTIONIST],
  /** Front-desk staff plus admins. */
  FRONT_DESK: [Role.RECEPTIONIST, Role.ADMIN, Role.SUPER_ADMIN],
  ADMINS: [Role.ADMIN, Role.SUPER_ADMIN],
  STAFF: [Role.COACH, Role.HEAD_COACH, Role.RECEPTIONIST, Role.ADMIN, Role.SUPER_ADMIN],
} as const satisfies Record<string, readonly RoleCode[]>;

/**
 * The mobile app the user lands in. A user holding several staff roles gets the
 * highest one: admin > coach > reception > member.
 */
export type AppRole = 'student' | 'coach' | 'reception' | 'admin';

export function primaryAppRole(roles: readonly string[]): AppRole {
  if (roles.includes(Role.ADMIN) || roles.includes(Role.SUPER_ADMIN)) return 'admin';
  if (roles.includes(Role.COACH) || roles.includes(Role.HEAD_COACH)) return 'coach';
  if (roles.includes(Role.RECEPTIONIST)) return 'reception';
  return 'student';
}
