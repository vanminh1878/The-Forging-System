import type { MembershipRepository, PackageTypeRow } from './membership.repository';

/** Package catalogue, memberships and renewal requests. */
export class MembershipService {
  constructor(private readonly repo: MembershipRepository) {}

  async listPackageTypes(includeInactive: boolean) {
    const rows = await this.repo.listPackageTypes(includeInactive);
    return rows.map(toPackageTypeView(includeInactive));
  }
}

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
