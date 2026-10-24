import { notFound } from '../../common/errors/app-error';
import { RoleGroup } from '../../shared/roles';
import type { BranchRepository } from './branch.repository';
import type { Branch } from './branch.types';

type Row = Branch & { qrVersion: string | null };

const isStaff = (roles: readonly string[]) =>
  roles.some((r) => (RoleGroup.STAFF as readonly string[]).includes(r));
const isAdmin = (roles: readonly string[]) =>
  roles.some((r) => (RoleGroup.ADMINS as readonly string[]).includes(r));

/** Members never see qrVersion; staff do. */
function present(row: Row, roles: readonly string[]): Branch {
  const { qrVersion, ...rest } = row;
  return isStaff(roles) ? { ...rest, qrVersion } : rest;
}

export class BranchService {
  constructor(private readonly repo: BranchRepository) {}

  async list(roles: readonly string[], includeInactive: boolean): Promise<Branch[]> {
    // Only admins may see inactive branches; everyone else silently gets the active ones.
    const rows = await this.repo.list(includeInactive && isAdmin(roles));
    return rows.map((r) => present(r, roles));
  }

  async get(id: string, roles: readonly string[]): Promise<Branch> {
    const row = await this.repo.findById(id);
    // Members must not learn that an inactive branch exists.
    if (!row || (!row.isActive && !isStaff(roles))) throw notFound('Chi nhánh');
    return present(row, roles);
  }
}
